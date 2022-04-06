// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {TestLand} from "./mocks/TestLand.sol";

import {SharedSetup, CheatCodes} from "./SharedSetup.t.sol";

import {IERC721Upgradeable} from "@openzeppelin-upgradable/contracts/token/ERC721/IERC721Upgradeable.sol";

import {DecentralandCollectionLibrary} from "../collections/decentraland/DecentralandCollectionLibrary.sol";
import {ICollectionLibrary} from "../collections/ICollectionLibrary.sol";
import {IRentable} from "../interfaces/IRentable.sol";

import {RentableTypes} from "./../RentableTypes.sol";

import {ORentable} from "../tokenization/ORentable.sol";
import {WRentable} from "../tokenization/WRentable.sol";

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

        testNFT.safeTransferFrom(user, address(rentable), tokenId);
        testNFT.safeTransferFrom(user, address(rentable), tokenId + 1);

        uint256 maxTimeDuration = 1000;
        uint256 pricePerSecond = 0.001 ether;

        RentableTypes.RentalConditions memory rc = RentableTypes
            .RentalConditions({
                paymentTokenAddress: address(0),
                paymentTokenId: 0,
                maxTimeDuration: maxTimeDuration,
                pricePerSecond: pricePerSecond,
                privateRenter: address(0)
            });

        rentable.createOrUpdateRentalConditions(address(testNFT), tokenId, rc);

        rentable.createOrUpdateRentalConditions(
            address(testNFT),
            tokenId + 1,
            rc
        );

        uint256 rentalDuration = 70;
        uint256 value = 0.07 ether;

        depositAndApprove(renter, value, address(0), 0);

        cheats.stopPrank();
        cheats.startPrank(renter);
        rentable.rent{value: value}(address(testNFT), tokenId, rentalDuration);
        cheats.stopPrank();

        cheats.startPrank(operator);

        rentable.SCRAM();

        cheats.stopPrank();

        cheats.startPrank(user);

        assert(rentable.paused());

        cheats.expectRevert(bytes("Pausable: paused"));
        rentable.withdraw(address(testNFT), tokenId);

        cheats.expectRevert(bytes("Pausable: paused"));
        rentable.expireRental(address(testNFT), 1);

        cheats.expectRevert(bytes("Pausable: paused"));
        orentable.transferFrom(user, operator, tokenId);

        cheats.stopPrank();
        cheats.startPrank(renter);
        cheats.expectRevert(bytes("Pausable: paused"));
        wrentable.transferFrom(renter, user, tokenId);
        cheats.stopPrank();

        cheats.startPrank(user);
        cheats.expectRevert(bytes("Pausable: paused"));
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
                IERC721Upgradeable.transferFrom.selector,
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
