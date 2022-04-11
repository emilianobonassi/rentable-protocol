// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.7;

import {TestLand} from "./mocks/TestLand.sol";

import {SharedSetup} from "./SharedSetup.t.sol";

import {DecentralandCollectionLibrary} from "../collections/decentraland/DecentralandCollectionLibrary.sol";
import {ICollectionLibrary} from "../collections/ICollectionLibrary.sol";
import {IRentable} from "../interfaces/IRentable.sol";

import {ORentable} from "../tokenization/ORentable.sol";
import {WRentable} from "../tokenization/WRentable.sol";

contract RentablePermissions is SharedSetup {
    function testSetLibraryOnlyGovernance() public {
        address someLibrary = vm.addr(44);
        address notGovernance = vm.addr(45);

        assertTrue(notGovernance != governance);

        vm.startPrank(governance);
        rentable.setLibrary(address(testNFT), someLibrary);
        vm.stopPrank();

        vm.startPrank(notGovernance);
        vm.expectRevert(bytes("Only Governance"));
        rentable.setLibrary(address(testNFT), someLibrary);
        vm.stopPrank();
    }
}
