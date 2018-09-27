pragma solidity ^0.4.24;

import "ds-test/test.sol";
import "ds-token/token.sol";
import "./polling.sol";


contract Voter {
    DSToken gov;
    Polling polling;

    constructor(DSToken _gov, Polling _polling) public {
        gov = _gov;
        polling = _polling;
    }

    function approve(uint amt) public {
        gov.approve(polling, amt);
    }

    function lock(uint amt) public {
        polling.lock(amt);
    }

    function try_free(uint amt) public returns (bool) {
        return address(polling).call(abi.encodeWithSignature(
            "free(uint256)", amt
        ));
    }

    function try_vote(uint amt, uint128 _pick, bytes _logData) public returns (bool) {
        return address(polling).call(abi.encodeWithSignature(
            "vote(uint256,uint128,bytes)", amt, _pick, _logData
        ));
    }

    function try_unSay(uint id) public returns (bool) {
        return address(polling).call(abi.encodeWithSignature(
            "unSay(uint256)", id
        ));
    }
}

contract WarpPolling is Polling {
    uint48 _era; uint32 _age;
    function warp(uint48 era_, uint32 age_) public { _era = era_; _age = age_; }
    function era() public view returns (uint48) { return _era; } 
    function age() public view returns (uint32) { return _age; }       
    constructor(DSToken _gov) public Polling(_gov) {}
}


contract PollingTest is DSTest {
    bytes32 digest = bytes32(1);
    uint8 hashFunction = 1;
    uint8 size = 1;
    bytes logData;

    DSToken gov;
    WarpPolling polling;
    Voter dan;
    Voter eli;

    function setUp() public {
        gov = new DSToken("GOV");
        polling = new WarpPolling(gov);
        polling.warp(1 hours, 1);
        dan = new Voter(gov, polling);
        eli = new Voter(gov, polling);
        gov.mint(200 ether);
        gov.transfer(dan, 100 ether);
        gov.transfer(eli, 100 ether);
    }

    function test_lock_free() public {
        dan.approve(100 ether);
        dan.lock(100 ether);
        assertEq(gov.balanceOf(dan), 0 ether);
        assertEq(gov.balanceOf(polling), 100 ether);
        assertTrue(dan.try_free(100 ether));
        assertEq(gov.balanceOf(dan), 100 ether);
        assertEq(gov.balanceOf(polling), 0 ether);
    }

    function test_create_poll() public {
        dan.approve(100 ether);
        dan.lock(100 ether);
        uint _id = polling.createPoll(1, 2, digest, hashFunction, size);
        (, uint48 _end, , uint _votesFor, uint _votesAgainst) = polling.getPoll(_id, 1);
        require(_end == 1 hours + 1 days);
        assertEq(_votesFor,     0 ether);
        assertEq(_votesAgainst, 0 ether);
    }

    function test_vote_switch_unsay() public {
        dan.approve(100 ether);
        dan.lock(100 ether);
        polling.warp(2 hours, 2); 
        uint _id = polling.createPoll(1, 2, digest, hashFunction, size);
        // cast vote
        assertTrue(dan.try_vote(_id, 1, logData));
        (, , , uint _votesFor, uint _votesAgainst) = polling.getPoll(_id, 1);
        assertEq(_votesFor, 100 ether);
        assertEq(_votesAgainst, 0 ether);
        // switch vote
        assertTrue(dan.try_vote(_id, 2, logData));
        (, , , uint votesFor_, uint votesAgainst_) = polling.getPoll(_id, 1);
        assertEq(votesFor_, 0 ether);
        assertEq(votesAgainst_, 100 ether);
        // withdraw vote
        assertTrue(dan.try_unSay(_id));
        (, , , uint _votesFor_, uint _votesAgainst_) = polling.getPoll(_id, 1);
        assertEq(_votesFor_, 0 ether);
        assertEq(_votesAgainst_, 0 ether);
    }

    function test_multi_warp() public {
        dan.approve(100 ether);
        eli.approve(100 ether);

        dan.lock(25 ether);
        eli.lock(50 ether);
        polling.warp(2 hours, 2); 
        // basic vote w/ 2 participants
        uint _id = polling.createPoll(1, 2, digest, hashFunction, size);
        assertTrue(dan.try_vote(_id, 1, logData));
        assertTrue(eli.try_vote(_id, 1, logData));
        (, , , uint _votesFor, uint _votesAgainst) = polling.getPoll(_id, 1);
        assertEq(_votesFor, 75 ether);
        assertEq(_votesAgainst, 0 ether);
        // additional locks aren't in this poll's snapshot
        dan.lock(50 ether);
        polling.warp(12 hours, 12); 
        assertTrue(dan.try_vote(_id, 2, logData));
        (, , , uint votesFor_, uint votesAgainst_) = polling.getPoll(_id, 1);
        assertEq(votesFor_, 50 ether);
        assertEq(votesAgainst_, 25 ether);
        // poll with 10 options
        uint id_ = polling.createPoll(2, 10, digest, hashFunction, size);
        assertTrue(dan.try_vote(id_, 1, logData));
        assertTrue(eli.try_vote(id_, 8, logData));
        (, , , uint _votesA,) = polling.getPoll(id_, 1);
        (, , , uint _votesH,) = polling.getPoll(id_, 8);
        assertEq(_votesA, 75 ether);
        assertEq(_votesH, 50 ether);

        assertTrue(dan.try_free(75 ether));
        assertEq(gov.balanceOf(dan), 100 ether);
        assertTrue(dan.try_vote(id_, 2, logData));
        (, , , , uint _votesB) = polling.getPoll(id_, 1);
        (, , , uint votesH_, ) = polling.getPoll(id_, 8);
        assertEq(votesH_, 50 ether);
        assertEq(_votesB, 75 ether);
    }

    function test_getters() public {
        dan.approve(100 ether);
        eli.approve(100 ether);
        dan.lock(100 ether);
        eli.lock(100 ether);
        polling.warp(2 hours, 2); 
        uint _id = polling.createPoll(1, 2, digest, hashFunction, size);
        // getVoterStatus
        (uint _voterStatus, uint _deposits) = polling.getVoterStatus(_id, dan);
        assertEq(_voterStatus, 0); // absent 
        assertEq(_deposits, 100 ether);
        assertTrue(dan.try_vote(_id, 1, logData));
        (uint voterStatus_, ) = polling.getVoterStatus(_id, dan);
        assertEq(voterStatus_, 1); // yea
        assertTrue(dan.try_vote(_id, 2, logData));
        (uint _voterStatus_, ) = polling.getVoterStatus(_id, dan);
        assertEq(_voterStatus_, 2); // nay

        (bytes32 _digest, uint _hashFunction, uint _size) = polling.getMultiHash(_id);
        assertEq(_digest, bytes32(1));
        assertEq(_hashFunction, 1);
        assertEq(_size, 1);
        // fake news polls
        (bytes32 digest_, , ) = polling.getMultiHash(100);
        assertEq(digest_, bytes32(0));
        (uint __voterStatus, uint __deposits) = polling.getVoterStatus(200, dan);
        assertEq(__voterStatus, 0);
        assertEq(__deposits, 0);
    }

    // Failure Cases ------------------------------------------------

    function test_fail_poll_expires_vote() public {
        dan.approve(100 ether);
        dan.lock(100 ether);
        uint _id = polling.createPoll(1, 2, digest, hashFunction, size);
        polling.warp(2 days, 2); 
        assertTrue(!dan.try_vote(_id, 1, logData));
    }

    function test_fail_poll_expires_unsay() public {
        dan.approve(100 ether);
        dan.lock(100 ether);
        uint _id = polling.createPoll(1, 2, digest, hashFunction, size);
        polling.warp(2 days, 2); 
        assertTrue(!dan.try_unSay(_id));
    }

    function test_fail_fake_poll_vote() public {
        dan.approve(100 ether);
        dan.lock(100 ether);
        polling.warp(2 hours, 2); 
        polling.createPoll(1, 2, digest, hashFunction, size);
        assertTrue(!dan.try_vote(200, 1, logData));
    }

    function test_fail_fake_poll_unsay() public {
        dan.approve(100 ether);
        dan.lock(100 ether);
        polling.warp(2 hours, 2); 
        polling.createPoll(1, 2, digest, hashFunction, size);
        assertTrue(!dan.try_unSay(200));
    }

    function test_fail_free_too_much() public {
        dan.approve(100 ether);
        eli.approve(100 ether);
        dan.lock(50 ether);
        eli.lock(50 ether);
        assertTrue(!dan.try_free(51 ether));
    }

    function test_fail_free_too_much_warp() public {
        dan.approve(100 ether);
        eli.approve(100 ether);
        dan.lock(50 ether);
        eli.lock(50 ether);
        polling.warp(100 days, 1000); 
        assertTrue(!dan.try_free(51 ether));
    }

    function test_fail_pick_out_of_range() public {
        dan.approve(100 ether);
        dan.lock(100 ether);
        polling.warp(2 hours, 2); 
        uint _id = polling.createPoll(1, 2, digest, hashFunction, size);
        assertTrue( dan.try_vote(_id, 1, logData));
        assertTrue( dan.try_vote(_id, 2, logData));
        assertTrue(!dan.try_vote(_id, 3, logData));
    }
}

