pragma solidity ^0.4.24;

// import "./polling.sol";
// import "ds-guard/guard.sol";

// contract PollingAuthority is DSAuth {
//     Polling polling;
//     constructor(Polling _polling) { polling = _polling; }
//     function setTTL(uint48 _ttl) { polling.setTTL(_ttl); }
//     function setDelay(uint48 _delay) { polling.setDelay(_delay); }
// }

// contract PollingSingleUseFab {
//     Polling polling;
//     DSRoles   roles;
//     PollingAuthority pollingAuthority;

//     function newPolling(DSToken _gov) public returns (address) {
//         uint8 timingRole = 0;
// 		uint8 pollCreatorRole = 1;

//         pollingAuthority = new PollingAuthority();
//         polling = new Polling(_gov);
//         roles = new DSRoles();

//         polling.setDelay(7 days);
//         polling.setTTL(7 days);

//         guard.setOwner(msg.sender);
//         polling.setAuthority(guard);

//         roles.setUserRole(pollingAuthority, timingRole, true);
//         roles.setRoleCapability(
//             pollingAuthority, polling, bytes4(keccak256("setDelay(uint48)")), true
//         );
//         roles.setRoleCapability(
//             pollingAuthority, polling, bytes4(keccak256("setTTL(uint48)")), true
//         );

// 		roles.setUserRole(this, pollCreatorRole, true);
//         roles.setRoleCapability(
//             pollCreatorRole, polling, bytes4(keccak256("createPoll(uint128,bytes32,uint8,uint8)")), true
//         );

//         return polling;
//     }
// }