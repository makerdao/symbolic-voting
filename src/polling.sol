pragma solidity ^0.4.24;

import "ds-token/token.sol";
import "ds-math/math.sol";
import "ds-auth/auth.sol";

contract PollingEvents {
    event PollCreated(
        uint256 id, 
        uint128 indexed numChoices, 
        uint64 start,
        uint64 end, 
        address indexed creator, 
        string multiHash
    );

    event PollWithdrawn(
        uint256 id, 
        address indexed creator, 
        uint256 timestamp
    );
    
    event Voted(
        address indexed lad, 
        uint256 indexed id, 
        uint128 indexed pick, 
        bytes logData
    );
}

// canonical event emitter 
contract PollingEmitter is PollingEvents, DSNote {
    mapping (address => uint256) public wards;
    function rely(address guy) public note auth { wards[guy] = 1; }
    function deny(address guy) public note auth { wards[guy] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    function createPoll(uint256 id, uint128 numChoices, uint64 start, uint64 end, string multiHash) 
        public view auth { emit PollCreated(id, numChoices, start, end, msg.sender, multiHash); }

    function vote(address lad, uint256 id, uint128 pick, bytes logData) 
        public view auth { emit Voted(lad, id, pick, logData); }

    function withdraw(uint256 id) 
        public view auth { emit PollWithdrawn(id, msg.sender, now); }
}

contract ResolveLike { 
    function canSpeakFor(address, address) public view returns (bool);
}

// emitter access control; upgradable 
contract PollingGuard is DSAuth, DSMath {
    string constant public VERSION = "0.1.0-alpha";

    PollingEmitter public polling;
    address public       resolver;
    uint256 public          npoll;
    DSToken public            gov; 

    mapping (uint256 => Poll) public polls;    

    struct Poll {
        uint64 start;
        uint64 end;      
        uint128 numChoices;
        bool withdrawn;
        address creator;
    }

    constructor(DSToken _gov, PollingEmitter _polling, address _resolver) 
        public { gov = _gov; polling = _polling; resolver = _resolver; }

    function createPoll(uint128 numChoices, uint64 delay, uint64 ttl, string multiHash) 
        public auth returns (uint256) 
    {
        require(ttl > 0, "poll must have a valid voting period");
        Poll storage poll = polls[npoll];
        uint64 _start = uint64(add(delay, now ));
        uint64 _end   = uint64(add(_start, ttl));

        poll.numChoices = numChoices;
        poll.creator    = msg.sender;
        poll.start      = _start;
        poll.end        = _end;

        polling.createPoll(npoll, numChoices, _start, _end, multiHash);
        return npoll++;
    }

    function vote(uint256 id, uint128 pick, bytes logData) 
        public { _vote(msg.sender, id, pick, logData); }

    function vote(address lad, uint256 id, uint128 pick, bytes logData) public {
        require(ResolveLike(resolver).canSpeakFor(msg.sender, lad), 
            "couldn't prove ownership of prospective address"
        );
        _vote(lad, id, pick, logData);
    }

    function _vote(address lad, uint256 id, uint128 pick, bytes logData) internal view {
        Poll storage poll = polls[id];

        require(id < npoll && !poll.withdrawn,  "id must be of a valid poll");
        require(now >= poll.start && now <= poll.end, "id must be of an active poll");
        require(gov.balanceOf(lad) > 0.005 ether, "voter must have more than 0.005 GOV");
        require(pick <= poll.numChoices, "pick must be within the choice range");

        polling.vote(lad, id, pick, logData);
    }

    function withdraw(uint256 id) public {
        Poll storage poll = polls[id];

        require(id < npoll && !poll.withdrawn,  "id must be of a valid poll");
        require(poll.creator == msg.sender, "poll must be withdrawn by its creator");
        require(poll.start > now, "poll can't be withdrawn after it has started");

        poll.withdrawn = true;
        polling.withdraw(id);
    }
}