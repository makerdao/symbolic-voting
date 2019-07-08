pragma solidity >=0.5.0;

import {DSTest} from "ds-test/test.sol";
import {PollingEmitter} from "./polling.sol";

contract Voter {
    PollingEmitter pollingEmitter;
    function setPolling(PollingEmitter pollingEmitter_) public { pollingEmitter = pollingEmitter_; }
}

contract PollingTest is DSTest {
    PollingEmitter pollingEmitter;

    function setUp() public {
        pollingEmitter = new PollingEmitter();
    }

    function test_can_log_create_poll() public {
        pollingEmitter.createPoll(1, 2, "", "");
    }

    function test_can_log_withdraw_poll() public {
        pollingEmitter.withdrawPoll(1);
    }

    function test_can_log_vote() public {
        pollingEmitter.vote(1, 1);
    }
}

