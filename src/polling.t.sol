pragma solidity ^0.4.24;

import "ds-test/test.sol";
import "ds-token/token.sol";

import {PollingSingleUseFab} from "./fab.sol";
import {PollingGuard, PollingEmitter} from "./polling.sol";
import {VoteProxyFactory, VoteProxy, DSChiefFab} from "./_vote-proxy-factory.sol";

contract Voter {
    PollingGuard pollingGuard;
    VoteProxyFactory voteProxyFactory;
    
    function setPolling(PollingGuard pollingGuard_) { pollingGuard = pollingGuard_; }

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

    PollingGuard pollingGuard;
    PollingEmitter pollingEmitter;
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
        (PollingEmitter pollingEmitter, PollingGuard pollingGuard) = pollingFab.newPolling(pollCreators);
        dan.setPolling(pollingGuard); 
        eli.setPolling(pollingGuard); 
        ned.setPolling(pollingGuard);

        // from _vote-proxy-factory contracts imported for testing ------------
        dan.setProxyFactory(voteProxyFactory); 
        eli.setProxyFactory(voteProxyFactory); 
        ned.setProxyFactory(voteProxyFactory);
        // --------------------------------------------------------------------
    }

    ////////////////////////////////
    ///////////// TODO /////////////
    ////////////////////////////////

}

