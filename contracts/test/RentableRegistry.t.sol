// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {SharedSetup, CheatCodes} from "./SharedSetup.t.sol";

import {ICollectionLibrary} from "../collectionlibs/ICollectionLibrary.sol";
import {IRentable} from "../IRentable.sol";

contract RentableRegistry is SharedSetup {
    function testRegistry() public {
        assertEq(rentable.getORentable(address(testNFT)), address(orentable));
        assertEq(rentable.getWRentable(address(testNFT)), address(wrentable));
    }
}
