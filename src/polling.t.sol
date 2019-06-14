pragma solidity ^0.4.24;

import "ds-test/test.sol";
import "ds-token/token.sol";

import {PollingEmitter} from "./polling.sol";

contract Voter {
    PollingEmitter pollingEmitter;
    function setPolling(PollingEmitter pollingEmitter_) public { pollingEmitter = pollingEmitter_; }
}

contract PollingTest is DSTest {
    bytes constant LOG_DATA = new bytes(1);

    PollingEmitter pollingEmitter;

    function setUp() public {
        pollingEmitter = new PollingEmitter();
    }

    function test_create_poll() public {
        pollingEmitter.createPoll(1, 1, 1, "");
    }
}

