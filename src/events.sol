pragma solidity ^0.4.24;


contract Events {
    event PollCreated(
        address indexed     src, 
        uint128 indexed choices,
        uint48 start, 
        uint48 end, 
        uint32 indexed frozenAt, 
        uint256 id
    );

    event Voted(
        address indexed src, 
        uint256 indexed id, 
        uint256 indexed pick, 
        uint256 weight, 
        bytes logData
    );

    event UnSaid(
        address indexed src, 
        uint256 indexed id, 
        uint256 weight
    );
}