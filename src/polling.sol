// Polling – create expiring straw polls 

pragma solidity ^0.4.24;

import "ds-math/math.sol";
import "ds-token/token.sol";
import "./events.sol";


contract Polling is DSMath, Events {
    uint256 public npoll;
    DSToken public   gov; 

    mapping (uint256 => Poll)         public    polls;    
    mapping (address => Checkpoint[]) public deposits;
    
    struct Checkpoint {
        uint128 fromBlock;
        uint128     value;
    }

    struct Multihash {
        bytes32 digest;
        uint8 hashFunction;
        uint8 size;
    }

    struct Poll {
        uint128 numChoices;
        uint32 frozenAt;
        uint48 start;
        uint48 end;            
        Multihash ipfsHash;
        mapping(address => uint128) votes; 
        mapping(uint128 => uint256) tally;
    }

    constructor(DSToken _gov) public { gov = _gov; }

    function era() public view returns (uint48) { return uint48(now); }
    function age() public view returns (uint32) { return uint32(block.number); }

    function lock(uint256 wad) public {
        gov.pull(msg.sender, wad);
        updateDeposits(deposits[msg.sender], add(getDeposits(msg.sender), wad));
    }

    function free(uint256 wad) public {
        updateDeposits(deposits[msg.sender], sub(getDeposits(msg.sender), wad));
        gov.push(msg.sender, wad);
    }

    function createPoll(uint48 ttl, uint128 numChoices, bytes32 digest, uint8 hashFunction, uint8 size) 
        public returns (uint256) 
    {
        require(ttl > 0, "poll must be live for at least one day");
        
        Poll storage poll = polls[npoll];
        uint32 _frozenAt  = age() - 1;
        uint48 _start     = era();
        uint48 _end       = uint48(add(_start, mul(ttl, 1 days)));

        poll.ipfsHash     = Multihash(digest, hashFunction, size);
        poll.frozenAt     = _frozenAt;
        poll.numChoices   = numChoices;
        poll.start        = _start;
        poll.end          = _end;

        emit PollCreated(msg.sender, numChoices, _start, _end, _frozenAt, npoll);

        return npoll++;
    }
    
    function vote(uint256 id, uint128 pick, bytes _logData) public {
        require(pollExists(id) && pollActive(id), "id must be of a valid and active poll");

        Poll storage poll = polls[id];
        uint256 weight = depositsAt(msg.sender, poll.frozenAt);
        require(weight > 0, "must have voting rights for this poll");
        require(pick   <= poll.numChoices, "pick must be within the choice range");

        subWeight(weight, msg.sender, poll);
        addWeight(weight, msg.sender, poll, pick);

        emit Voted(msg.sender, id, pick, weight, _logData);
    }
             
    function unSay(uint256 id) public {
        require(pollExists(id) && pollActive(id), "id must be of a valid and active poll");

        Poll storage poll = polls[id];
        uint256 weight = depositsAt(msg.sender, poll.frozenAt);
        require(weight > 0, "must have voting rights for this poll");

        subWeight(weight, msg.sender, poll);
        poll.votes[msg.sender] = 0;

        emit UnSaid(msg.sender, id, weight);
    }

    // Internal -----------------------------------------------------

    function updateDeposits(Checkpoint[] storage checkpoints, uint256 _value) internal {
        if ((checkpoints.length == 0) || (checkpoints[checkpoints.length - 1].fromBlock < age())) {
            Checkpoint storage newCheckPoint = checkpoints[checkpoints.length++];
            newCheckPoint.fromBlock = age();
            newCheckPoint.value = uint128(_value);
        } else {
            Checkpoint storage oldCheckPoint = checkpoints[checkpoints.length - 1];
            oldCheckPoint.value = uint128(_value);
        }
    }

    function subWeight(uint256 _weight, address _guy, Poll storage poll) internal {
        if (poll.votes[_guy] != 0) {
            poll.tally[poll.votes[_guy]] = sub(poll.tally[poll.votes[_guy]], _weight);
        }
    }

    function addWeight(uint256 _weight, address _guy, Poll storage poll, uint128 _pick) internal {
        poll.tally[_pick] = add(poll.tally[_pick], _weight);
        poll.votes[_guy]  = _pick;
    }

    // Getters ------------------------------------------------------

    function getDeposits(address guy) public view returns (uint256) {
        return depositsAt(guy, age());
    }

    // logic adapted from the minime token https://github.com/Giveth/minime –> credit Jordi Baylina
    function depositsAt(address _guy, uint256 _block) public view returns (uint) {
        Checkpoint[] storage checkpoints = deposits[_guy];
        if (checkpoints.length == 0) return 0;
        if (_block >= checkpoints[checkpoints.length - 1].fromBlock)
            return checkpoints[checkpoints.length - 1].value;
        if (_block < checkpoints[0].fromBlock) return 0;
        uint256 min = 0;
        uint256 max = checkpoints.length - 1;
        while (max > min) {
            uint256 mid = (max + min + 1) / 2;
            if (checkpoints[mid].fromBlock <= _block) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return checkpoints[min].value;
    }

    function pollExists(uint256 id) public view returns (bool) {
        return id < npoll;
    }

    function pollActive(uint256 id) public view returns (bool) {
        return era() < polls[id].end;
    }

    function getPoll(uint256 id, uint128 pick) 
        public view returns (uint48, uint48, uint32, uint256, uint256) 
    {
        Poll storage poll = polls[id];
        return (poll.start, poll.end, poll.frozenAt, poll.tally[pick], poll.tally[pick+1]);
    }
    
    function getVoterStatus(uint256 id, address guy) public view returns (uint128, uint256) {
        Poll storage poll = polls[id];
        return (poll.votes[guy], depositsAt(guy, poll.frozenAt));
    }

    function getMultiHash(uint256 id) public view returns (bytes32, uint256, uint256) {
        Multihash storage multihash = polls[id].ipfsHash;
        return (multihash.digest, uint256(multihash.hashFunction), uint256(multihash.size));
    }
}