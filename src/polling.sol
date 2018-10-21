// Polling – create expiring straw polls 

pragma solidity ^0.4.24;

import "ds-math/math.sol";
import "ds-token/token.sol";

// contract Resolver {
//     constructor(DSToken _proxyFactory) public { proxyFactory = _proxyFactory; }
//     function resolve(address caller, address prospect) public returns (bool) {
//         return (
//             proxyFactory.coldMap(caller) == prospect || 
//             proxyFactory.hotMap(caller)  == prospect
//         );
//     }
// }

contract Polling is DSThing {
    uint256 public npoll;
    DSToken public   gov; 

    // poll lifecycle; configurable via auth
    uint48 public delay;
    uint48 public   ttl;

    mapping (uint256 => Poll) public polls;    

    struct Multihash {
        bytes32 digest;
        uint8 hashFunction;
        uint8 size;
    }

    struct Poll {
        uint48 end;      
        uint48 start;
        uint128 numChoices;
        bool withdrawn;
        address creator;
        address[] voters;
        Multihash documentHash;
        mapping(address => uint128) votes; 
    }

    constructor(DSToken _gov) public { gov = _gov; }

    function createPoll(uint128 numChoices, bytes32 digest, uint8 hashFunction, uint8 size) 
        public auth note returns (uint256) 
    {
        Poll storage poll = polls[npoll];
        uint48 _start     = add(now, delay);
        uint48 _end       = add(_start, ttl);

        poll.documentHash = Multihash(digest, hashFunction, size);
        poll.numChoices   = numChoices;
        poll.creator      = msg.sender;
        poll.start        = _start;
        poll.end          = _end;

        return npoll++;
    }
    
    function vote(address lad, uint256 id, uint128 pick, bytes _logData) internal note {
        require(isValidPoll(id) && pollActive(id), "id must be of a valid and active poll");
        Poll storage poll = polls[id];

        require(pick <= poll.numChoices, "pick must be within the choice range");
        poll.votes[lad] = pick;
        poll.voters.push(lad);
    }

    function vote(uint256 id, uint128 pick, bytes _logData) public {
        vote(msg.sender, id, pick, _logData);
    }

    function vote(address lad, uint256 id, uint128 pick, bytes _logData) public {
        require(resolver.resolve(msg.sender, lad));
        vote(lad, id, pick, _logData);
    }

    function withdraw(uint256 id) public note {
        require(isValidPoll(id));
        Poll storage poll = polls[id];
        require(poll.start < now);
        require(poll.creator == msg.sender);
        poll.withdrawn = true;
    }

    function setDelay (uint48 _delay) public auth { delay = _delay; }
    function setTTL   ( uint48 _ttl ) public auth { ttl   =   _ttl; }

    function isValidPoll(uint256 id) public view returns (bool) {
        return (id < npoll && !polls[id].withdrawn);
    }

    function pollActive(uint256 id) public view returns (bool) {
        return (now >= polls[id].start && now <= polls[id].end);
    }

    function getMultiHash(uint256 id) public view returns (bytes32, uint256, uint256) {
        Multihash storage multihash = polls[id].documentHash;
        return (multihash.digest, uint256(multihash.hashFunction), uint256(multihash.size));
    }
}