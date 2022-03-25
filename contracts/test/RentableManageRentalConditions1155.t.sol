// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {SharedSetup1155, CheatCodes} from "./SharedSetup1155.t.sol";

import {IRentable1155} from "../IRentable1155.sol";

contract RentableManageRentalConditions1155 is SharedSetup1155 {
    function preAssertsRentalConditions(
        uint256 oTokenId,
        address paymentTokenAddress,
        uint256 paymentTokenId,
        uint256 maxTimeDuration,
        uint256 pricePerBlock,
        address privateRenter
    ) public {
        // Test event emitted
        cheats.expectEmit(true, true, true, true);
        emit UpdateRentalConditions(
            address(orentable),
            oTokenId,
            paymentTokenAddress,
            paymentTokenId,
            maxTimeDuration,
            pricePerBlock,
            privateRenter
        );
    }

    function assertRentalConditions(
        uint256 oTokenId,
        uint256 maxTimeDuration,
        uint256 pricePerBlock,
        address paymentToken,
        uint256 paymentTokenId,
        address privateRenter
    ) public {
        IRentable1155.RentalConditions memory rc = rentable.rentalConditions(
            address(testNFT),
            oTokenId
        );

        assertEq(rc.maxTimeDuration, maxTimeDuration);
        assertEq(rc.pricePerBlock, pricePerBlock);
        assertEq(rc.paymentTokenAddress, paymentToken);
        assertEq(rc.paymentTokenId, paymentTokenId);
        assertEq(rc.privateRenter, privateRenter);
    }

    function testCreateRentalConditions() public {
        /**
        Test deposit and create rental conditions
     */

        cheats.startPrank(user);

        uint256 tokenId = 123;
        uint256 mintAmount = 5;
        uint256 depositAmount = 5;
        uint256 maxTimeDuration = 10000;
        uint256 pricePerBlock = 10;

        testNFT.mint(user, tokenId, mintAmount);
        testNFT.setApprovalForAll(address(rentable), true);

        uint256 oTokenId = 1;

        rentable.deposit(address(testNFT), tokenId, depositAmount, 0);

        preAssertsRentalConditions(
            oTokenId,
            address(0),
            0,
            maxTimeDuration,
            pricePerBlock,
            address(0)
        );

        rentable.createOrUpdateRentalConditions(
            address(testNFT),
            oTokenId,
            address(0),
            0,
            maxTimeDuration,
            pricePerBlock,
            address(0)
        );

        // Check rentalCondition created correctly
        assertRentalConditions(
            oTokenId,
            maxTimeDuration,
            pricePerBlock,
            address(0),
            0,
            address(0)
        );
    }

    function testDeleteRentalConditions() public {
        /**
        Test delete rental conditions
     */

        cheats.startPrank(user);

        uint256 tokenId = 123;
        uint256 mintAmount = 5;
        uint256 depositAmount = 5;
        uint256 maxTimeDuration = 10000;
        uint256 pricePerBlock = 10;

        testNFT.mint(user, tokenId, mintAmount);
        testNFT.setApprovalForAll(address(rentable), true);

        uint256 oTokenId = 1;

        rentable.deposit(address(testNFT), tokenId, depositAmount, 0);

        rentable.createOrUpdateRentalConditions(
            address(testNFT),
            oTokenId,
            address(0),
            0,
            maxTimeDuration,
            pricePerBlock,
            address(0)
        );

        rentable.deleteRentalConditions(address(testNFT), oTokenId);

        assertEq(
            rentable
                .rentalConditions(address(testNFT), tokenId)
                .maxTimeDuration,
            0
        );
    }

    function testUpdateRentalConditions() public {
        /**
        Test update rental conditions
     */

        cheats.startPrank(user);

        uint256 tokenId = 123;
        uint256 mintAmount = 5;
        uint256 depositAmount = 5;
        uint256 maxTimeDuration = 10000;
        uint256 pricePerBlock = 10;

        testNFT.mint(user, tokenId, mintAmount);
        testNFT.setApprovalForAll(address(rentable), true);

        uint256 oTokenId = 1;

        rentable.deposit(address(testNFT), tokenId, depositAmount, 0);

        rentable.createOrUpdateRentalConditions(
            address(testNFT),
            oTokenId,
            address(0),
            0,
            maxTimeDuration,
            pricePerBlock,
            address(0)
        );

        maxTimeDuration = 8000;
        pricePerBlock = 80;

        preAssertsRentalConditions(
            oTokenId,
            address(0),
            0,
            maxTimeDuration,
            pricePerBlock,
            address(0)
        );

        rentable.createOrUpdateRentalConditions(
            address(testNFT),
            oTokenId,
            address(0),
            0,
            maxTimeDuration,
            pricePerBlock,
            address(0)
        );
        // Check rentalCondition created correctly
        assertRentalConditions(
            oTokenId,
            maxTimeDuration,
            pricePerBlock,
            address(0),
            0,
            address(0)
        );
    }

    function testCannotManageRentalConditionsNotOwner() public {
        /**
        Test only owner can update rental conditions
     */

        cheats.startPrank(user);

        uint256 tokenId = 123;
        uint256 mintAmount = 5;
        uint256 depositAmount = 5;
        uint256 maxTimeDuration = 10000;
        uint256 pricePerBlock = 10;

        testNFT.mint(user, tokenId, mintAmount);
        testNFT.setApprovalForAll(address(rentable), true);

        uint256 oTokenId = 1;

        rentable.deposit(address(testNFT), tokenId, depositAmount, 0);

        cheats.stopPrank();
        cheats.startPrank(cheats.addr(24));
        cheats.expectRevert(bytes("The token must be yours"));
        rentable.createOrUpdateRentalConditions(
            address(testNFT),
            oTokenId,
            address(0),
            0,
            maxTimeDuration,
            pricePerBlock,
            address(0)
        );

        cheats.expectRevert(bytes("The token must be yours"));
        rentable.deleteRentalConditions(address(testNFT), oTokenId);
    }
}
