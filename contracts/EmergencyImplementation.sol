pragma solidity ^0.8.11;

contract EmergencyImplementation {
    fallback() external payable {
        revert("Emergency in place");
    }
}
