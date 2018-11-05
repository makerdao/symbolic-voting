// PollingSingleUseFab – create a polling system and store relevant values for auditability 

pragma solidity ^0.4.24;

import "./polling.sol";
import "./vote-proxy-resolver.sol";

import "ds-guard/guard.sol";

contract PollingSingleUseFab {
    address public resolver;
    PollingEmitter public pollingEmitter;
    PollingGuard public pollingGuard;
    DSGuard public guard;
    DSToken public gov;

    constructor(address voteProxyFactory, DSToken _gov) {
        resolver = new VoteProxyResolver(voteProxyFactory);
        gov = _gov;
    }

    function newPolling(address[] lads) public returns (PollingEmitter, PollingGuard) {
        pollingEmitter = new PollingEmitter();
        pollingGuard = new PollingGuard(gov, pollingEmitter, resolver);
        pollingEmitter.rely(pollingGuard);
        pollingEmitter.deny(this);
        guard = new DSGuard();
        for (uint256 i = 0; i < lads.length; i++) 
            guard.permit(lads[i], pollingGuard, bytes4(keccak256("createPoll(uint128,uint64,uint64,string)")));
        pollingGuard.setAuthority(guard);
        guard.setOwner(msg.sender);
        return (pollingEmitter, pollingGuard);
    }
}