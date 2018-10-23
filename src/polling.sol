// Polling – create expiring straw polls 

pragma solidity ^0.4.24;

import "ds-token/token.sol";
import "ds-math/math.sol";
import "ds-auth/auth.sol";


contract ResolveLike { 
    function canSpeakFor(address, address) public view returns (bool);
}

contract Polling is DSMath, DSAuth {
    string constant public VERSION = "0.1.0-alpha";
    string public rules; 
    
    address public resolver;
    uint256 public    npoll;
    DSToken public      gov; 
    DSToken public      iou; 

    mapping (uint256 => Poll) public polls;    

    struct Poll {
        uint64 start;
        uint64 end;      
        uint128 numChoices;
        bool withdrawn;
        address creator;
        address[] voters;
        string documentHash;
        mapping(address => uint128) votes; 
        mapping(address => uint256) indices;
    }

    event PollCreated(
        uint256 id, uint128 indexed numChoices, uint64 start,
        uint64 end, address indexed creator, string multiHash
    );
    event PollWithdrawn(uint256 id, address indexed creator, uint256 timestamp);
    event Voted(address indexed lad, uint256 indexed id, uint128 indexed pick, bytes logData);

    constructor(DSToken _gov, DSToken _iou, address _resolver, string _rules) public 
        { gov = _gov; iou = _iou; resolver = _resolver; rules = _rules; }

    function createPoll(uint128 numChoices, uint64 delay, uint64 ttl, string multiHash) 
        public auth returns (uint256) 
    {
        Poll storage poll = polls[npoll];

        require(ttl > 0, "poll must have a valid voting period");
        uint64 _start = uint64(add(delay, now ));
        uint64 _end   = uint64(add(_start, ttl));

        poll.documentHash = multiHash;
        poll.numChoices   = numChoices;
        poll.creator      = msg.sender;
        poll.start        = _start;
        poll.end          = _end;

        emit PollCreated(npoll, numChoices, _start, _end, msg.sender, multiHash);

        return npoll++;
    }

    function vote(uint256 id, uint128 pick, bytes logData) public {
        _vote(msg.sender, id, pick, logData);
    }

    function vote(address lad, uint256 id, uint128 pick, bytes logData) public {
        require(
            ResolveLike(resolver).canSpeakFor(msg.sender, lad), 
            "couldn't prove ownership of prospective address"
        );
        _vote(lad, id, pick, logData);
    }

    function _vote(address lad, uint256 id, uint128 pick, bytes logData) internal {
        require(isValidPoll(id) && pollActive(id), "id must be of a valid and active poll");
        require(
            gov.balanceOf(lad) > 0.005 ether || iou.balanceOf(lad) > 0.005 ether, 
            "voter must have more than 0.005 GOV or IOU"
        );

        Poll storage poll = polls[id];
        require(pick <= poll.numChoices, "pick must be within the choice range");

        // push voter onto the voter array if they're voting
        if (pick > 0 && poll.votes[lad] == 0) poll.indices[lad] = poll.voters.push(lad) - 1;
        // pop voter from the voter array if they're now abstaining
        else if (pick == 0 && poll.votes[lad] > 0) {
            poll.voters[poll.indices[lad]] = poll.voters[poll.voters.length - 1];
            poll.indices[poll.voters[poll.voters.length - 1]] = poll.indices[lad];
            poll.voters.length--;
            delete poll.indices[lad];
        }

        poll.votes[lad] = pick;
        emit Voted(lad, id, pick, logData);
    }

    function withdraw(uint256 id) public {
        require(isValidPoll(id), "id must be of a valid poll");
        Poll storage poll = polls[id];
        require(poll.creator == msg.sender, "poll must be withdrawn by its creator");
        require(poll.start > now, "poll can't be withdrawn after it has started");
        poll.withdrawn = true;
        emit PollWithdrawn(id, msg.sender, now);
    }

    // Views ------------------------------------------------------------------

    function isValidPoll(uint256 id) public view returns (bool) {
        return (id < npoll && !polls[id].withdrawn);
    }

    function pollActive(uint256 id) public view returns (bool) {
        return (now >= polls[id].start && now <= polls[id].end);
    }

    function getPollParams(uint256 id)
        public view returns (uint64, uint64, uint128, bool, address) 
    {
        Poll storage poll = polls[id];
        return (poll.start, poll.end, poll.numChoices, poll.withdrawn, poll.creator);
    }

    function getMultiHash(uint256 id) public view returns (string) {
        return polls[id].documentHash;
    }

    function checkVote(uint256 id, address lad) public view returns (uint128) {
        return polls[id].votes[lad];
    }

    function getVoter(uint256 id, uint256 index) public view returns (address) {
        return polls[id].voters[index];
    }

    function getVoterCount(uint256 id) public view returns (uint256) {
        return polls[id].voters.length;
    }
}