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

contract RentableSCRAM is SharedSetup {
    function testSCRAM() public {
        cheats.startPrank(user);
        //2 subscription, SCRAM, operation stopped, safe withdrawal by governance
        address renter = cheats.addr(10);

        uint256 tokenId = 123;
        testNFT.mint(user, tokenId);
        testNFT.mint(user, tokenId + 1);
        testNFT.mint(user, tokenId + 2);

        testNFT.approve(address(rentable), tokenId);
        testNFT.approve(address(rentable), tokenId + 1);

        rentable.deposit(address(testNFT), tokenId);
        rentable.deposit(address(testNFT), tokenId + 1);

        uint256 maxTimeDuration = 1000;
        uint256 pricePerSecond = 0.001 ether;

        rentable.createOrUpdateRentalConditions(
            address(testNFT),
            tokenId,
            address(0),
            0,
            maxTimeDuration,
            pricePerSecond,
            address(0)
        );

        rentable.createOrUpdateRentalConditions(
            address(testNFT),
            tokenId + 1,
            address(0),
            0,
            maxTimeDuration,
            pricePerSecond,
            address(0)
        );

        uint256 rentalDuration = 70;
        uint256 value = 0.07 ether;

        depositAndApprove(renter, value, address(0), 0);

        cheats.startPrank(renter);
        rentable.rent{value: value}(address(testNFT), tokenId, rentalDuration);
        cheats.stopPrank();

        cheats.startPrank(operator);

        rentable.SCRAM();

        cheats.stopPrank();

        cheats.startPrank(user);

        assert(rentable.paused());

        cheats.expectRevert(bytes("Emergency in place"));
        rentable.withdraw(address(testNFT), tokenId);

        cheats.expectRevert(bytes("Emergency in place"));
        rentable.expireRental(address(testNFT), 1);

        cheats.expectRevert(bytes("Emergency in place"));
        orentable.transferFrom(user, operator, tokenId);

        cheats.stopPrank();
        cheats.startPrank(renter);
        cheats.expectRevert(bytes("Emergency in place"));
        wrentable.transferFrom(renter, user, tokenId);
        cheats.stopPrank();

        cheats.startPrank(user);
        cheats.expectRevert(bytes("Emergency in place"));
        testNFT.safeTransferFrom(user, address(rentable), tokenId + 2);
        cheats.stopPrank();
        /*
    Test safe withdrawal by governance
    1. exec emergency operation
    2. withdrawal single
    3. withdrawal batch
    */

        cheats.startPrank(governance);
        rentable.emergencyExecute(
            address(testNFT),
            0,
            abi.encodeWithSelector(
                IERC721.transferFrom.selector,
                address(rentable),
                governance,
                tokenId
            ),
            false,
            200000
        );
        cheats.stopPrank();

        assertEq(testNFT.ownerOf(tokenId), governance);

        cheats.startPrank(governance);
        rentable.emergencyWithdrawERC721(address(testNFT), tokenId + 1, true);
        assertEq(testNFT.ownerOf(tokenId + 1), governance);
        cheats.stopPrank();
    }
}
