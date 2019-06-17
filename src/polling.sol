pragma solidity >=0.5.0;

contract PollingEvents {
    event PollCreated(
        address indexed creator,
        uint256 pollId,
        uint256 startBlock,
        uint256 endBlock,
        string multiHash
    );

    event PollWithdrawn(
        address indexed creator,
        uint256 pollId,
        uint256 blockNumber
    );

    event Voted(
        address indexed voter,
        uint256 indexed pollId,
        uint256 indexed optionId
    );
}

contract PollingEmitter is PollingEvents {
    uint256 public npoll;

    function createPoll(uint256 startBlock, uint256 endBlock, string calldata multiHash)
        external
    {
        emit PollCreated(
            msg.sender,
            npoll,
            startBlock > block.number ? startBlock : block.number,
            endBlock,
            multiHash
        );
        npoll++;
    }

    function withdrawPoll(uint256 pollId)
        external
    {
        emit PollWithdrawn(msg.sender, pollId, block.number);
    }

    function vote(uint256 pollId, uint256 optionId)
        external
    {
        emit Voted(msg.sender, pollId, optionId);
    }
}

