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

    function free(uint amt) public {
        polling.free(amt);
    }

    function vote(uint amt, bool _yea, bytes _logData) public {
        polling.vote(amt, _yea, _logData);
    }

    function unSay(uint id) public {
        polling.unSay(id);
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
        dan.free(100 ether);
        assertEq(gov.balanceOf(dan), 100 ether);
        assertEq(gov.balanceOf(polling), 0 ether);
    }

    function test_create_poll() public {
        dan.approve(100 ether);
        dan.lock(100 ether);
        uint _id = polling.createPoll(1, digest, hashFunction, size);
        (, uint48 _end, , uint _votesFor, uint _votesAgainst) = polling.getPoll(_id);
        require(_end == 1 hours + 1 days);
        assertEq(_votesFor, 0 ether);
        assertEq(_votesAgainst, 0 ether);
    }

    function test_vote_switch_unsay() public {
        dan.approve(100 ether);
        dan.lock(100 ether);
        polling.warp(2 hours, 2); 
        uint _id = polling.createPoll(1, digest, hashFunction, size);
        // cast vote
        dan.vote(_id, true, logData);
        (, , , uint _votesFor, uint _votesAgainst) = polling.getPoll(_id);
        assertEq(_votesFor, 100 ether);
        assertEq(_votesAgainst, 0 ether);
        // switch vote
        dan.vote(_id, false, logData);
        (, , , uint votesFor_, uint votesAgainst_) = polling.getPoll(_id);
        assertEq(votesFor_, 0 ether);
        assertEq(votesAgainst_, 100 ether);
        // withdraw vote
        dan.unSay(_id);
        (, , , uint _votesFor_, uint _votesAgainst_) = polling.getPoll(_id);
        assertEq(_votesFor_, 0 ether);
        assertEq(_votesAgainst_, 0 ether);
    }

    function test_multi_warp() public {
        dan.approve(100 ether);
        eli.approve(100 ether);

        dan.lock(25 ether);
        eli.lock(50 ether);
        polling.warp(2 hours, 2); 

        uint _id = polling.createPoll(1, digest, hashFunction, size);
        dan.vote(_id, true, logData);
        eli.vote(_id, true, logData);
        (, , , uint _votesFor, uint _votesAgainst) = polling.getPoll(_id);
        assertEq(_votesFor, 75 ether);
        assertEq(_votesAgainst, 0 ether);

        dan.lock(50 ether);
        polling.warp(12 hours, 12); 
        dan.vote(_id, false, logData);
        (, , , uint votesFor_, uint votesAgainst_) = polling.getPoll(_id);
        assertEq(votesFor_, 50 ether);
        assertEq(votesAgainst_, 25 ether);

        uint id_ = polling.createPoll(2, digest, hashFunction, size);
        dan.vote(id_, true, logData);
        eli.vote(id_, true, logData);
        (, , , uint _votesFor_, uint _votesAgainst_) = polling.getPoll(id_);
        assertEq(_votesFor_, 125 ether);
        assertEq(_votesAgainst_, 0 ether);
        dan.free(75 ether);
        assertEq(gov.balanceOf(dan), 100 ether);
        dan.vote(id_, false, logData);
        (, , , uint __votesFor, uint __votesAgainst) = polling.getPoll(id_);
        assertEq(__votesFor, 50 ether);
        assertEq(__votesAgainst, 75 ether);
    }

    function test_getters() public {
        dan.approve(100 ether);
        eli.approve(100 ether);
        dan.lock(100 ether);
        eli.lock(100 ether);
        polling.warp(2 hours, 2); 
        uint _id = polling.createPoll(1, digest, hashFunction, size);
        // getVoterStatus
        (uint _voterStatus, uint _deposits) = polling.getVoterStatus(_id, dan);
        assertEq(_voterStatus, 0); // absent 
        assertEq(_deposits, 100 ether);
        dan.vote(_id, true, logData);
        (uint voterStatus_, ) = polling.getVoterStatus(_id, dan);
        assertEq(voterStatus_, 1); // yea
        dan.vote(_id, false, logData);
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

    function testFail_poll_expires_vote() public {
        dan.approve(100 ether);
        dan.lock(100 ether);
        uint _id = polling.createPoll(1, digest, hashFunction, size);
        polling.warp(2 days, 2); 
        dan.vote(_id, true, logData);
    }

    function testFail_poll_expires_unsay() public {
        dan.approve(100 ether);
        dan.lock(100 ether);
        uint _id = polling.createPoll(1, digest, hashFunction, size);
        polling.warp(2 days, 2); 
        dan.unSay(_id);
    }

    function testFail_fake_poll_vote() public {
        dan.approve(100 ether);
        dan.lock(100 ether);
        polling.warp(2 hours, 2); 
        polling.createPoll(1, digest, hashFunction, size);
        dan.vote(200, true, logData);
    }

    function testFail_fake_poll_unsay() public {
        dan.approve(100 ether);
        dan.lock(100 ether);
        polling.warp(2 hours, 2); 
        polling.createPoll(1, digest, hashFunction, size);
        dan.unSay(200);
    }

    function testFail_free_too_much() public {
        dan.approve(100 ether);
        eli.approve(100 ether);
        dan.lock(50 ether);
        eli.lock(50 ether);
        dan.free(51 ether);
    }

    function testFail_free_too_much_warp() public {
        dan.approve(100 ether);
        eli.approve(100 ether);
        dan.lock(50 ether);
        eli.lock(50 ether);
        polling.warp(100 days, 1000); 
        dan.free(51 ether);
    }
}

