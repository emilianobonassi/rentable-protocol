// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.7;

import {SharedSetup} from "./SharedSetup.t.sol";

import {ICollectionLibrary} from "../collections/ICollectionLibrary.sol";
import {IRentable} from "../interfaces/IRentable.sol";

contract RentableRegistry is SharedSetup {
    function testRegistry() public {
        assertEq(rentable.getORentable(address(testNFT)), address(orentable));
        assertEq(rentable.getWRentable(address(testNFT)), address(wrentable));
    }
}
