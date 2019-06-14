pragma solidity >=0.5.0;

contract PollingEvents {
    event PollCreated(
        address indexed sender,
        uint256 pollId,
        uint128 indexed numChoices,
        uint64 startBlock,
        uint64 endBlock,
        string multiHash
    );

    event PollWithdrawn(
        address indexed sender,
        uint256 pollId,
        uint256 blockNumber
    );

    event Voted(
        address indexed sender,
        uint256 indexed pollId,
        uint128 indexed pick,
        bytes logData
    );
}

contract PollingEmitter is PollingEvents {
    string constant public VERSION = "1.0.0";
    uint256 public npoll;

    function createPoll(uint128 numChoices, uint64 startBlock, uint64 endBlock, string memory multiHash)
        public view {
            emit PollCreated(msg.sender, npoll, numChoices, startBlock, endBlock, multiHash);
            npoll++;
    }

    function withdrawPoll(uint256 pollId)
        public view { emit PollWithdrawn(msg.sender, pollId, block.number); }

    function vote(uint256 pollId, uint128 pick, bytes memory logData)
        public view { emit Voted(msg.sender, pollId, pick, logData); }
}

