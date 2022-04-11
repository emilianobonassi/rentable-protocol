// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.7;

import {SharedSetup} from "./SharedSetup.t.sol";

contract RentablePermissions is SharedSetup {
    function testSetLibraryOnlyGovernance() public executeByUser(governance) {
        rentable.setLibrary(address(testNFT), getNewAddress());

        switchUser(getNewAddress());
        vm.expectRevert(bytes("Only Governance"));
        rentable.setLibrary(address(testNFT), getNewAddress());
    }
}
