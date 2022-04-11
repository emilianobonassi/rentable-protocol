// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.7;

import {Vm} from "forge-std/Vm.sol";

contract TestHelper {
    // Helper generating new unique addresses
    uint256 addressesGenerated = 0;

    Vm private vm_test_helper =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function getNewAddress() internal returns (address) {
        addressesGenerated++;

        return vm_test_helper.addr(addressesGenerated);
    }

    function switchUser(address newUser) internal {
        vm_test_helper.stopPrank();
        vm_test_helper.startPrank(newUser);
    }

    modifier executeByUser(address user) {
        vm_test_helper.startPrank(user);
        _;
        vm_test_helper.stopPrank();
    }
}
