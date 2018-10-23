// VoteProxyResolver – determine if a caller is the owner of a vote-proxy

pragma solidity ^0.4.24;

contract ProxyFactoryLike {
    function coldMap(address) public returns (address);
    function hotMap (address) public returns (address);
}

contract VoteProxyResolver {
    ProxyFactoryLike proxyFactory;
    constructor(address _proxyFactory) public { proxyFactory = ProxyFactoryLike(_proxyFactory); }
    function canSpeakFor(address caller, address prospect) public returns (bool) {
        return (
            proxyFactory.coldMap(caller) == prospect || proxyFactory.hotMap(caller) == prospect
        );
    }
}