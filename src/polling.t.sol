pragma solidity >=0.5.0;

import {DSTest} from "ds-test/test.sol";
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

    function test_can_emit_create_poll_event() public {
        pollingEmitter.createPoll(1, "");
    }
}

