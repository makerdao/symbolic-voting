pragma solidity >=0.5.0;

import {DSTest} from "ds-test/test.sol";
import {PollingEmitter} from "./polling.sol";

// contract Voter {
//     PollingEmitter pollingEmitter;
//     function setPolling(PollingEmitter pollingEmitter_) public { pollingEmitter = pollingEmitter_; }
// }

contract PollingTest is DSTest {
    PollingEmitter pollingEmitter;

    function setUp() public {
        pollingEmitter = new PollingEmitter();
    }

    function test_can_log_create_poll() public {
        pollingEmitter.createPoll(1, 2, "");
    }

    function test_can_log_withdraw_poll() public {
        pollingEmitter.withdrawPoll(1);
    }

    function test_can_log_withdraw_poll_multiple() public {
        uint256[] memory polls = new uint256[](3);
        polls[0] = uint256(1);
        polls[1] = uint256(2);
        polls[2] = uint256(3);
        pollingEmitter.withdrawPoll(polls);
    }

    function test_can_log_vote() public {
        pollingEmitter.vote(1, 1);
    }

    function test_can_log_vote_multiple() public {
        uint256[] memory polls = new uint256[](3);
        polls[0] = uint256(1);
        polls[1] = uint256(2);
        polls[2] = uint256(3);
        uint256[] memory options = new uint256[](3);
        options[0] = uint256(2);
        options[1] = uint256(3);
        options[2] = uint256(1);
        pollingEmitter.vote(polls, options);
    }

    function testFail_can_log_vote_multiple() public {
        uint256[] memory polls = new uint256[](3);
        polls[0] = uint256(1);
        polls[1] = uint256(2);
        polls[2] = uint256(3);
        uint256[] memory options = new uint256[](2);
        options[0] = uint256(2);
        options[1] = uint256(3);
        pollingEmitter.vote(polls, options);
    }
}

