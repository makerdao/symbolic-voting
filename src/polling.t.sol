pragma solidity ^0.4.24;

import "ds-test/test.sol";
import "ds-token/token.sol";

import "./polling.sol";

contract Voter {
    Polling polling;
    constructor(Polling _polling) public { polling = _polling; }

    function createPoll(uint128 _numChoices, uint64 _delay, uint64 _ttl, string _multiHash) 
        public returns (uint256) 
    {
        return polling.createPoll(_numChoices, _delay, _ttl, _multiHash);
    }

    function getPollParams(uint256 _id)
        public view returns (uint256, uint256, uint256, bool, address) 
    {
        return polling.getPollParams(_id);
    }

    function try_vote(uint _id, uint128 _pick, bytes _logData) public returns (bool) {
        return address(polling).call(abi.encodeWithSignature(
            "vote(uint256,uint128,bytes)", _id, _pick, _logData
        ));
    }

    function try_vote(address _lad, uint _id, uint128 _pick, bytes _logData) public returns (bool) {
        return address(polling).call(abi.encodeWithSignature(
            "vote(address,uint256,uint128,bytes)", _lad, _id, _pick, _logData
        ));
    }
}

contract Resolver {
    function canSpeakFor(address caller, address prospect) public view returns (bool) {
        return true;
    }
}

contract Hevm {
    function warp(uint256) public;
}

contract PollingTest is DSTest {
    bytes constant LOG_DATA = new bytes(1);

    Hevm hevm;
    Polling polling;

    DSToken gov;
    DSToken iou;
    Voter dan;
    Voter eli;

    function setUp() public {
        // HEVM cheat -> can set the block timestamp
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(100);

        gov = new DSToken("GOV");
        iou = new DSToken("IOU");
        gov.mint(200 ether);

        polling = new Polling(gov, iou, new Resolver(), "");

        dan = new Voter(polling);
        eli = new Voter(polling);
        gov.transfer(dan, 100 ether);
        gov.transfer(eli, 100 ether);

        polling.setOwner(dan);
    }

    function test_create_polls() public {
        assertEq(polling.npoll(), 0);
        uint256 id = dan.createPoll(2, 0, 1 days, "multiHash");
        assertEq(polling.npoll(), 1);
        assertEq(id, 0);

        uint256 _id = dan.createPoll(100, 0, 1 days, "multiHash");
        assertEq(polling.npoll(), 2);
        assertEq(_id, 1);
    }

    function test_getters() public {
        uint id = dan.createPoll(5, 0, 1 days, "multiHash");

        (uint256 start, uint256 end, uint256 numChoices, 
            bool withdrawn, address creator) = polling.getPollParams(id);
        assertEq(start, 100);
        assertEq(end, 100 + 1 days);
        assertTrue(!withdrawn);
        assertEq(creator, dan);
        assertEq(numChoices, 5);

        (string memory multiHash) = polling.getMultiHash(id);
        assertEq(keccak256(multiHash), keccak256("multiHash"));

        // dan hasn't voted so his pick is implicitly "0" 
        (uint256 pick) = uint256(polling.checkVote(id, dan));
        assertEq(pick, 0);

        // no voters yet
        assertEq(polling.getVoterCount(id), 0); 

        // anyone can call the getters
        (uint256 _start, ,,,) = dan.getPollParams(id);
        assertEq(_start, 100);
        (uint256 start_, ,,,) = eli.getPollParams(id);
        assertEq(start_, 100);
    }

    function test_voting() public {
        // create a poll with 2 options: "1" & "2"
        uint id = dan.createPoll(2, 0, 1 days, "multiHash");

        // dan votes for option 1
        assertTrue(dan.try_vote(id, 1, new bytes(0)));
        assertEq(polling.getVoter(id, 0), dan);
        assertEq(uint256(polling.checkVote(id, dan)), 1);
        assertEq(polling.getVoterCount(id), 1); 

        // eli votes for option 2
        assertTrue(eli.try_vote(id, 2, new bytes(0)));
        assertEq(polling.getVoter(id, 1), eli);
        assertEq(uint256(polling.checkVote(id, eli)), 2);
        assertEq(polling.getVoterCount(id), 2); 

        // dan's pick is still accounted for properly
        assertEq(polling.getVoter(id, 0), dan);
        assertEq(uint256(polling.checkVote(id, dan)), 1);

        // dan switches to option 2
        assertTrue(dan.try_vote(id, 2, new bytes(0)));
        assertEq(polling.getVoter(id, 0), dan);
        assertEq(uint256(polling.checkVote(id, dan)), 2);
        assertEq(polling.getVoterCount(id), 2); 

        // eli's pick is still accounted for properly
        assertEq(polling.getVoter(id, 1), eli);
        assertEq(uint256(polling.checkVote(id, eli)), 2);

        // dan decides to abstain
        assertTrue(dan.try_vote(id, 0, new bytes(0)));
        assertEq(polling.getVoter(id, 0), dan);
        assertEq(uint256(polling.checkVote(id, dan)), 0); 
    }

    function test_proxy_voting() public {
        // create a poll with 2 options: "1" & "2"
        uint id = dan.createPoll(2, 0, 1 days, "multiHash");
        assertTrue(dan.try_vote(eli, id, 2, new bytes(0)));
        assertEq(polling.getVoter(id, 0), eli);
        assertEq(uint256(polling.checkVote(id, eli)), 2);
        assertEq(polling.getVoterCount(id), 1); 
    }

    // Failure cases --------------------------------------

    function test_fail_out_of_range_pick() public {
        // 2 choices
        uint id = dan.createPoll(2, 0, 1 days, "multiHash");

        // can't vote for an option "3"
        assertTrue(!dan.try_vote(id, 3, new bytes(0)));

        // can vote for an option "3"
        assertTrue(dan.try_vote(id, 1, new bytes(0)));
    }

    function test_fail_invalid_voting_periods() public {
        // set block timestamp to 0
        hevm.warp(0);

        // this poll starts in 5 days and expires in 10
        uint id = dan.createPoll(2, 5 days, 5 days, "multiHash");

        // can't vote on a queued poll
        assertTrue(!dan.try_vote(id, 1, new bytes(0)));

        // set block timestamp forward 5 days
        hevm.warp(5 days);
        // can vote the moment a poll has become active
        assertTrue(dan.try_vote(id, 1, new bytes(0)));
        // can vote after the poll has become active
        hevm.warp(6 days);
        assertTrue(dan.try_vote(id, 1, new bytes(0)));
        // can vote the second the poll ends
        hevm.warp(10 days);
        assertTrue(dan.try_vote(id, 1, new bytes(0)));

        // can't vote after a poll has ended
        hevm.warp(11 days);
        assertTrue(!dan.try_vote(id, 1, new bytes(0)));
    }
}

