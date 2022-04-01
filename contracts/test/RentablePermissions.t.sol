// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {TestLand} from "./utils/TestLand.sol";

import {SharedSetup, CheatCodes} from "./SharedSetup.t.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {DecentralandCollectionLibrary} from "../collectionlibs/decentraland/DecentralandCollectionLibrary.sol";
import {ICollectionLibrary} from "../collectionlibs/ICollectionLibrary.sol";
import {IRentable} from "../IRentable.sol";

import {ORentable} from "../ORentable.sol";
import {WRentable} from "../WRentable.sol";

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
