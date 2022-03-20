// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

contract EmergencyImplementation {
    fallback() external payable {
        revert("Emergency in place");
    }
}
