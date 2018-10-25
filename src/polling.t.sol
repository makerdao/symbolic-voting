pragma solidity ^0.4.24;

import "ds-test/test.sol";
import "ds-token/token.sol";

import "./fab.sol";
import "./polling.sol";
import "./_vote-proxy-factory.sol";

contract Voter {
    Polling polling;
    VoteProxyFactory voteProxyFactory;
    
    function setPolling(Polling _polling) { polling = _polling; }

    function getPollParams(uint256 _id)
        public view returns (uint256, uint256, uint256, bool, address) 
    {
        return polling.getPollParams(_id);
    }

    function createPoll(uint128 _numChoices, uint64 _delay, uint64 _ttl, string _multiHash) 
        public returns (uint256) 
    {
        return polling.createPoll(_numChoices, _delay, _ttl, _multiHash);
    }

    function try_withdrawPoll(uint256 _id) public returns (bool) {
        return address(polling).call(abi.encodeWithSignature(
            "withdraw(uint256)", _id
        ));
    }

    function try_createPoll(uint128 _numChoices, uint64 _delay, uint64 _ttl, string _multiHash) 
        public returns (bool) 
    {
        return address(polling).call(abi.encodeWithSignature(
            "createPoll(uint128,uint64,uint64,string)", _numChoices, _delay, _ttl, _multiHash
        ));
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

    // for proxy voting tests -------------------------------------------------
    function setProxyFactory(VoteProxyFactory _voteProxyFactory) 
        { voteProxyFactory = _voteProxyFactory; }
    function initiateLink(address hot) public { voteProxyFactory.initiateLink(hot); }
    function approveLink(address cold) public returns (VoteProxy) { return voteProxyFactory.approveLink(cold); }
    // ------------------------------------------------------------------------
}

contract Hevm {
    function warp(uint256) public;
}

contract PollingTest is DSTest {
    bytes constant LOG_DATA = new bytes(1);

    PollingSingleUseFab pollingFab;
    VoteProxyFactory voteProxyFactory;

    Polling polling;
    DSToken gov;
    DSToken iou;
    Hevm hevm;
    Voter dan;
    Voter eli;
    Voter ned;

    function setUp() public {
        // HEVM cheat -> set the block timestamp
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(100);

        gov = new DSToken("GOV");
        iou = new DSToken("IOU");
        gov.mint(400 ether);

        // from _vote-proxy-factory contracts imported for testing ------------
        DSChiefFab dsChiefFab = new DSChiefFab();
        voteProxyFactory = new VoteProxyFactory(dsChiefFab.newChief(gov, 5));
        // --------------------------------------------------------------------

        pollingFab = new PollingSingleUseFab(voteProxyFactory, gov);

        dan = new Voter();
        eli = new Voter();
        ned = new Voter();
        gov.transfer(dan, 100 ether);
        gov.transfer(eli, 100 ether);
        gov.transfer(ned, 100 ether);

        address[] memory pollCreators = new address[](2);
        pollCreators[0] = dan;
        pollCreators[1] = eli;
        polling = pollingFab.newPolling(pollCreators, "");
        dan.setPolling(polling); 
        eli.setPolling(polling); 
        ned.setPolling(polling);

        // from _vote-proxy-factory contracts imported for testing ------------
        dan.setProxyFactory(voteProxyFactory); 
        eli.setProxyFactory(voteProxyFactory); 
        ned.setProxyFactory(voteProxyFactory);
        // --------------------------------------------------------------------
    }

    function test_create_polls() public {
        assertEq(polling.npoll(), 0);
        uint256 id = dan.createPoll(2, 0, 1 days, "multiHash");
        assertEq(polling.npoll(), 1);
        assertEq(id, 0);
        assertEq(polling.npoll(), 1);

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

        // ned can vote, too :)
        assertTrue(ned.try_vote(id, 2, new bytes(0)));
        assertEq(polling.getVoter(id, 2), ned);
        assertEq(polling.getVoterCount(id), 3); 

        // dan decides to abstain
        assertTrue(dan.try_vote(id, 0, new bytes(0)));
        assertEq(uint256(polling.checkVote(id, dan)), 0); 
        assertEq(polling.getVoterCount(id), 2);
        assertEq(polling.getVoter(id, 0), ned); // ned moves to dan's position
        assertEq(polling.getVoter(id, 1), eli); // eli remains

        // dan decides to vote for option 1 again
        assertTrue(dan.try_vote(id, 1, new bytes(0)));
        assertEq(uint256(polling.checkVote(id, dan)), 1); 
        assertEq(polling.getVoterCount(id), 3);
        assertEq(polling.getVoter(id, 0), ned);
        assertEq(polling.getVoter(id, 1), eli);
        assertEq(polling.getVoter(id, 2), dan);

        // now eli abstains
        assertTrue(eli.try_vote(id, 0, new bytes(0)));
        assertEq(uint256(polling.checkVote(id, eli)), 0); 
        assertEq(polling.getVoterCount(id), 2);
        assertEq(polling.getVoter(id, 0), ned); 
        assertEq(polling.getVoter(id, 1), dan); // dan moves to eli's position
    }

    function test_proxy_voting() public {
        // from imported proxy factory contracts ------------------------------
        dan.initiateLink(eli);
        VoteProxy voteProxy = eli.approveLink(dan);
        gov.transfer(voteProxy, 100 ether);
        // --------------------------------------------------------------------

        // create a poll with 2 options: "1" & "2"
        uint id = dan.createPoll(2, 0, 1 days, "multiHash");

        // dan can speak for the proxy
        assertTrue(dan.try_vote(voteProxy, id, 2, new bytes(0)));
        assertEq(polling.getVoter(id, 0), voteProxy);
        assertEq(uint256(polling.checkVote(id, voteProxy)), 2);
        assertEq(polling.getVoterCount(id), 1); 

        // eli can speak for the proxy
        assertTrue(eli.try_vote(voteProxy, id, 1, new bytes(0)));
        assertEq(polling.getVoter(id, 0), voteProxy);
        assertEq(uint256(polling.checkVote(id, voteProxy)), 1);
        assertEq(polling.getVoterCount(id), 1); 

        // ned cannot speak for the proxy
        assertTrue(!ned.try_vote(voteProxy, id, 1, new bytes(0)));
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

    function test_fail_poll_creator_auth() {
        // dan was given auth
        assertTrue(dan.try_createPoll(2, 0, 1 days, "multiHash"));
        // ned wasn't given auth
        assertTrue(!ned.try_createPoll(2, 0, 1 days, "multiHash"));
        // eli was given auth
        assertTrue(eli.try_createPoll(2, 0, 1 days, "multiHash"));
    }

    function test_fail_vote_withdrawn_poll() {
        // set block timestamp to 0
        hevm.warp(0);

        // this poll starts in 5 days and expires in 10
        uint id = dan.createPoll(2, 5 days, 5 days, "multiHash");
        // only the poll creator can withdraw
        assertTrue(!eli.try_withdrawPoll(id));
        assertTrue(dan.try_withdrawPoll(id));

        // warp to a valid voting period
        hevm.warp(6 days);
        // nobody can vote on this poll since it's been withdrawn
        assertTrue(!dan.try_vote(id, 1, new bytes(0)));
        assertTrue(!eli.try_vote(id, 1, new bytes(0)));
    }

    function test_fail_internal_voting_function() {
        uint id = dan.createPoll(2, 0, 1 days, "multiHash");
        assertTrue(address(polling).call(abi.encodeWithSignature(
            "vote(uint256,uint128,bytes)", id, 1, new bytes(0)
        )));
        assertTrue(!address(polling).call(abi.encodeWithSignature(
            "_vote(address,uint256,uint128,bytes)", this, id, 1, new bytes(0)
        )));
    }
}

