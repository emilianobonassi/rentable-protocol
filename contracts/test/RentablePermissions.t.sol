// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {TestLand} from "./mocks/TestLand.sol";

import {SharedSetup, CheatCodes} from "./SharedSetup.t.sol";

import {DecentralandCollectionLibrary} from "../collections/decentraland/DecentralandCollectionLibrary.sol";
import {ICollectionLibrary} from "../collections/ICollectionLibrary.sol";
import {IRentable} from "../interfaces/IRentable.sol";

import {ORentable} from "../tokenization/ORentable.sol";
import {WRentable} from "../tokenization/WRentable.sol";

contract RentablePermissions is SharedSetup {
    function testSetLibraryOnlyGovernance() public {
        address someLibrary = cheats.addr(44);
        address notGovernance = cheats.addr(45);

        assertTrue(notGovernance != governance);

        cheats.startPrank(governance);
        rentable.setLibrary(address(testNFT), someLibrary);
        cheats.stopPrank();

        cheats.startPrank(notGovernance);
        cheats.expectRevert(bytes("Only Governance"));
        rentable.setLibrary(address(testNFT), someLibrary);
        cheats.stopPrank();
    }
}
