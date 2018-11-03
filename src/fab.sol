// PollingSingleUseFab – create a polling system and store relevant values for auditability

pragma solidity ^0.4.24;

import "./polling.sol";
import "./vote-proxy-resolver.sol";

import "ds-guard/guard.sol";

contract PollingSingleUseFab {
    address  resolver;
    Polling   polling;
    DSGuard     guard;
    DSToken       gov;

    constructor(address voteProxyFactory, DSToken _gov) {
        resolver = new VoteProxyResolver(voteProxyFactory);
        gov = _gov;
    }

    function newPolling(address[] lads, string rules) public returns (Polling) {
        polling = new Polling(gov, resolver, rules);
        guard   = new DSGuard();
        for (uint256 i = 0; i < lads.length; i++)
            guard.permit(lads[i], polling, bytes4(keccak256("createPoll(uint128,uint64,uint64,string)")));
        polling.setAuthority(guard);
        guard.setOwner(msg.sender);
        return polling;
    }
}
