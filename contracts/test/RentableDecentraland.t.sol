// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {TestLand} from "./utils/TestLand.sol";

import {SharedSetup, CheatCodes} from "./SharedSetup.t.sol";

import {DecentralandCollectionLibrary} from "../collectionlibs/decentraland/DecentralandCollectionLibrary.sol";
import {ICollectionLibrary} from "../collectionlibs/ICollectionLibrary.sol";
import {IRentable} from "../IRentable.sol";

import {OLandRegistry} from "../collectionlibs/decentraland/OLandRegistry.sol";
import {ILandRegistry} from "../collectionlibs/decentraland/ILandRegistry.sol";
import {WRentable} from "../WRentable.sol";

import {RentableTypes} from "./../RentableTypes.sol";

contract RentableDecentraland is SharedSetup {
    TestLand testLand;
    DecentralandCollectionLibrary decentralandCollectionLibrary;

    function setUp() public override {
        super.setUp();

        cheats.startPrank(governance);

        testLand = new TestLand();

        orentable = new OLandRegistry(
            address(testLand),
            governance,
            address(rentable)
        );
        rentable.setORentable(address(testLand), address(orentable));

        wrentable = new WRentable(
            address(testLand),
            governance,
            address(rentable)
        );
        rentable.setWRentable(address(testLand), address(wrentable));

        decentralandCollectionLibrary = new DecentralandCollectionLibrary();
        rentable.setLibrary(
            address(testLand),
            address(decentralandCollectionLibrary)
        );

        rentable.enableProxyCall(
            address(orentable),
            ILandRegistry.setUpdateOperator.selector,
            true
        );

        cheats.stopPrank();
    }

    function testFlow() public {
        /** 
        Land owned by originalOwner and with originalOperator as operator
        List for maxSeconds and pricePerSecond payed in currencyToken
        Onwer transfer to newOwner
        Renter rent for half of the time
        Transfer to newRenter
        newOwner redeem after expire*/

        address originalOwner = cheats.addr(10);
        uint256 tokenId = 123;
        address originalOperator = cheats.addr(11);
        address renter = cheats.addr(12);
        address newRenter = cheats.addr(13);
        address newOwner = cheats.addr(14);
        address offRentableOperator = cheats.addr(15);

        cheats.startPrank(originalOwner);

        testLand.mint(originalOwner, tokenId);
        assertEq(testLand.ownerOf(tokenId), originalOwner);

        testLand.setUpdateOperator(tokenId, originalOperator);
        assertEq(testLand.updateOperator(tokenId), originalOperator);

        uint256 maxTimeDuration = 10;
        uint256 pricePerSecond = 0.1 ether;

        testLand.safeTransferFrom(
            originalOwner,
            address(rentable),
            tokenId,
            abi.encode(
                RentableTypes.RentalConditions({
                    maxTimeDuration: maxTimeDuration,
                    pricePerSecond: pricePerSecond,
                    paymentTokenId: 0,
                    paymentTokenAddress: address(0),
                    privateRenter: address(0)
                })
            )
        );

        assertEq(testLand.updateOperator(tokenId), originalOwner);
        cheats.warp(1); //timestamp is 0 otw
        //owner must be able to change operator when rentals are not in place
        ILandRegistry(address(orentable)).setUpdateOperator(
            tokenId,
            offRentableOperator
        );
        assertEq(
            ILandRegistry(address(orentable)).updateOperator(tokenId),
            offRentableOperator
        );

        //non-owners cannot change rentals
        cheats.stopPrank();
        cheats.startPrank(newOwner);
        cheats.expectRevert(bytes("User not allowed"));
        ILandRegistry(address(orentable)).setUpdateOperator(
            tokenId,
            offRentableOperator
        );
        cheats.stopPrank();
        cheats.startPrank(originalOwner);

        //Transfer ownership not rented should change operator
        orentable.safeTransferFrom(originalOwner, newOwner, tokenId);
        assertEq(testLand.updateOperator(tokenId), newOwner);

        //After changing ownership the original owner must not be allowed to change operator
        cheats.expectRevert(bytes("User not allowed"));
        ILandRegistry(address(orentable)).setUpdateOperator(
            tokenId,
            offRentableOperator
        );

        // new owner must be able to change operator when rentals are not in place
        cheats.stopPrank();
        cheats.startPrank(newOwner);
        ILandRegistry(address(orentable)).setUpdateOperator(
            tokenId,
            offRentableOperator
        );
        assertEq(testLand.updateOperator(tokenId), offRentableOperator);

        //Rent
        cheats.stopPrank();
        cheats.startPrank(renter);
        depositAndApprove(renter, 1 ether, address(0), 0);

        rentable.rent{value: 1 ether}(
            address(testLand),
            tokenId,
            maxTimeDuration / 2
        );

        // Transfer newRenter
        wrentable.safeTransferFrom(renter, newRenter, tokenId);
        assertEq(testLand.updateOperator(tokenId), newRenter);

        cheats.stopPrank();
        cheats.startPrank(newOwner);

        // owner can't change operator during rental
        cheats.expectRevert(bytes("Operation not allowed during rental"));
        ILandRegistry(address(orentable)).setUpdateOperator(
            tokenId,
            offRentableOperator
        );

        // Transfer ownership rented - must not change operator
        orentable.safeTransferFrom(newOwner, originalOwner, tokenId);
        assertEq(testLand.updateOperator(tokenId), newRenter);

        cheats.warp(maxTimeDuration / 2 + 1);

        // update must be possible after lease expired even if not explicitly
        cheats.stopPrank();
        cheats.startPrank(originalOwner);
        ILandRegistry(address(orentable)).setUpdateOperator(
            tokenId,
            offRentableOperator
        );
        assertEq(
            ILandRegistry(address(orentable)).updateOperator(tokenId),
            offRentableOperator
        );

        rentable.expireRental(address(testLand), tokenId);

        // Original Owner will be the updateOperator again

        assertEq(testLand.updateOperator(tokenId), originalOwner);

        cheats.stopPrank();
        cheats.startPrank(originalOwner);

        rentable.withdraw(address(testLand), tokenId);

        assertEq(testLand.updateOperator(tokenId), address(0));

        cheats.stopPrank();
    }
}
