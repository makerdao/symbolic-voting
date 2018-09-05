pragma solidity ^0.4.24;

import "ds-test/test.sol";

import "./SymbolicVoting.sol";

contract SymbolicVotingTest is DSTest {
    SymbolicVoting voting;

    function setUp() public {
        voting = new SymbolicVoting();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
