// SPDX-License-Identifier: MIT

pragma solidity >=0.8.7;

contract DummyEmergencyHelper {
    address private immutable original;

    uint256 public field;

    constructor() {
        original = address(this);
    }

    function setField(uint256 _field) public {
        field = _field;
    }

    function revertOnDelegate() public view {
        require(address(this) == original, "Called via delegate");
    }
}
