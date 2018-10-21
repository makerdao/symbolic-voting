pragma solidity ^0.4.24;

import "ds-test/test.sol";
import "ds-token/token.sol";
import "./polling.sol";


contract Voter {
    DSToken gov;
    Polling polling;

    constructor(DSToken _gov, Polling _polling) public {
        gov = _gov;
        polling = _polling;
    }

    function approve(uint amt) public {
        gov.approve(polling, amt);
    }

    function lock(uint amt) public {
        polling.lock(amt);
    }

    function try_free(uint amt) public returns (bool) {
        return address(polling).call(abi.encodeWithSignature(
            "free(uint256)", amt
        ));
    }

    function try_vote(uint amt, uint128 _pick, bytes _logData) public returns (bool) {
        return address(polling).call(abi.encodeWithSignature(
            "vote(uint256,uint128,bytes)", amt, _pick, _logData
        ));
    }

    function try_unSay(uint id) public returns (bool) {
        return address(polling).call(abi.encodeWithSignature(
            "unSay(uint256)", id
        ));
    }
}

contract WarpPolling is Polling {
    uint48 _era; uint32 _age;
    function warp(uint48 era_, uint32 age_) public { _era = era_; _age = age_; }
    function era() public view returns (uint48) { return _era; } 
    function age() public view returns (uint32) { return _age; }       
    constructor(DSToken _gov) public Polling(_gov) {}
}


contract PollingTest is DSTest {
    bytes32 digest = bytes32(1);
    uint8 hashFunction = 1;
    uint8 size = 1;
    bytes logData;

    DSToken gov;
    WarpPolling polling;
    Voter dan;
    Voter eli;

    function setUp() public {
        gov = new DSToken("GOV");
        polling = new WarpPolling(gov);
        polling.warp(1 hours, 1);
        dan = new Voter(gov, polling);
        eli = new Voter(gov, polling);
        gov.mint(200 ether);
        gov.transfer(dan, 100 ether);
        gov.transfer(eli, 100 ether);
    }

    function test_create_poll() public {
        uint _id = polling.createPoll(2, digest, hashFunction, size);
        (, uint48 _end, , uint _votesFor, uint _votesAgainst) = polling.Poll(_id);
    }
}

