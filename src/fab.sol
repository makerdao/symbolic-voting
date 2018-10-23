pragma solidity ^0.4.24;

import "./polling.sol";
import "./vote-proxy-resolver.sol";

import "ds-guard/guard.sol";

contract PollingSingleUseFab {
    Resolver resolver;
    Polling   polling;
    DSGuard     guard;
    DSToken       gov;
    DSToken       iou;

    constructor(address voteProxyFactory, DSToken _gov, DSToken _iou) {
        resolver = new Resolver(voteProxyFactory);
        gov = _gov;
        iou = _iou;
    }

    function newPolling(address[] lads, string rules) public returns (address) {
        polling = new Polling(gov, iou, resolver, rules);
        guard   = new DSGuard();
        for (uint256 i = 0; i < lads.length; i++) 
            guard.permit(lads[i], polling, bytes4(keccak256("createPoll(uint128,uint64,uint64,string)")));
        guard.setOwner(msg.sender);
        polling.setAuthority(guard);
        return polling;
    }
}