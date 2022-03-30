// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {SharedSetup, CheatCodes} from "./SharedSetup.t.sol";

import {ICollectionLibrary} from "../collectionlibs/ICollectionLibrary.sol";
import {IRentable} from "../IRentable.sol";

import {RentableTypes} from "./../RentableTypes.sol";

contract RentableTest is SharedSetup {
    function preAssertsTestDeposit(uint256 tokenId) internal {
        // Test event emitted
        cheats.expectEmit(true, true, true, true);
        emit Deposit(user, address(testNFT), tokenId);

        // Test dummy library
        bytes memory expectedData = abi.encodeCall(
            ICollectionLibrary.postDeposit,
            (address(testNFT), tokenId, user)
        );
        cheats.expectCall(address(dummyLib), expectedData);
    }

    function postAssertsTestDeposit(uint256 tokenId) internal {
        // Test ownership is on orentable
        assertEq(testNFT.ownerOf(tokenId), address(rentable));

        // Test user ownership
        assertEq(orentable.ownerOf(tokenId), user);
    }

    function preAssertsUpdateRentalConditions(
        uint256 tokenId,
        address paymentTokenAddress,
        uint256 paymentTokenId,
        uint256 maxTimeDuration,
        uint256 pricePerSecond,
        address privateRenter
    ) internal {
        // Test event emitted
        cheats.expectEmit(true, true, true, true);

        emit UpdateRentalConditions(
            address(testNFT),
            tokenId,
            paymentTokenAddress,
            paymentTokenId,
            maxTimeDuration,
            pricePerSecond,
            privateRenter
        );

        bytes memory expectedData = abi.encodeCall(
            ICollectionLibrary.postList,
            (address(testNFT), tokenId, user, maxTimeDuration, pricePerSecond)
        );
        cheats.expectCall(address(dummyLib), expectedData);
    }

    function postAssertsUpdateRentalConditions(
        uint256 tokenId,
        address paymentTokenAddress,
        uint256 paymentTokenId,
        uint256 maxTimeDuration,
        uint256 pricePerSecond,
        address privateRenter
    ) internal {
        RentableTypes.RentalConditions memory rcs = rentable.rentalConditions(
            address(testNFT),
            tokenId
        );
        assertEq(rcs.maxTimeDuration, maxTimeDuration);
        assertEq(rcs.pricePerSecond, pricePerSecond);
        assertEq(rcs.paymentTokenAddress, paymentTokenAddress);
        assertEq(rcs.paymentTokenId, paymentTokenId);
        assertEq(rcs.privateRenter, privateRenter);
    }

    function testDeposit() public {
        cheats.startPrank(user);

        uint256 tokenId = 123;

        for (uint256 i = 0; i < 2; i++) {
            prepareTestDeposit(tokenId);

            if (i == 0) {
                //traditional
                rentable.deposit(address(testNFT), tokenId);
            } else {
                //1tx
                testNFT.safeTransferFrom(user, address(rentable), tokenId);
            }

            postAssertsTestDeposit(tokenId);

            tokenId++;
        }

        cheats.stopPrank();
    }

    function testDepositAndList() public {
        cheats.startPrank(user);

        uint256 maxTimeDuration = 1000;
        uint256 pricePerSecond = 0.001 ether;

        address paymentTokenAddress = address(0);
        uint256 paymentTokenId = 0;
        address[2] memory privateRenters = [address(0), cheats.addr(5)];
        uint256 tokenId = 123;

        for (uint256 j = 0; j < 2; j++) {
            address privateRenter = privateRenters[j];
            for (uint256 i = 0; i < 2; i++) {
                prepareTestDeposit(tokenId);

                preAssertsTestDeposit(tokenId);
                preAssertsUpdateRentalConditions(
                    tokenId,
                    paymentTokenAddress,
                    paymentTokenId,
                    maxTimeDuration,
                    pricePerSecond,
                    privateRenter
                );

                if (i == 0) {
                    //traditional
                    rentable.depositAndList(
                        address(testNFT),
                        tokenId,
                        paymentTokenAddress,
                        paymentTokenId,
                        maxTimeDuration,
                        pricePerSecond,
                        privateRenter
                    );
                } else {
                    //1tx
                    testNFT.safeTransferFrom(
                        user,
                        address(rentable),
                        tokenId,
                        abi.encode(
                            RentableTypes.RentalConditions({
                                maxTimeDuration: maxTimeDuration,
                                pricePerSecond: pricePerSecond,
                                paymentTokenId: paymentTokenId,
                                paymentTokenAddress: paymentTokenAddress,
                                privateRenter: privateRenter
                            })
                        )
                    );
                }

                postAssertsTestDeposit(tokenId);

                postAssertsUpdateRentalConditions(
                    tokenId,
                    paymentTokenAddress,
                    paymentTokenId,
                    maxTimeDuration,
                    pricePerSecond,
                    privateRenter
                );

                tokenId++;
            }
        }

        cheats.stopPrank();
    }

    function testWithdraw() public {
        cheats.startPrank(user);

        uint256 tokenId = 123;

        prepareTestDeposit(tokenId);
        rentable.deposit(address(testNFT), tokenId);

        cheats.expectEmit(true, true, true, true);
        emit Withdraw(address(testNFT), tokenId);

        rentable.withdraw(address(testNFT), tokenId);

        cheats.expectRevert(bytes("ERC721: owner query for nonexistent token"));

        orentable.ownerOf(tokenId);

        assertEq(testNFT.ownerOf(tokenId), user);

        cheats.stopPrank();
    }

    function testCreateRentalConditions() public {
        cheats.startPrank(user);

        uint256 maxTimeDuration = 1000;
        uint256 pricePerSecond = 0.001 ether;

        address paymentTokenAddress = address(0);
        uint256 paymentTokenId = 0;
        address[2] memory privateRenters = [address(0), cheats.addr(5)];
        uint256 tokenId = 123;

        for (uint256 j = 0; j < 2; j++) {
            address privateRenter = privateRenters[j];
            prepareTestDeposit(tokenId);

            rentable.deposit(address(testNFT), tokenId);

            preAssertsUpdateRentalConditions(
                tokenId,
                paymentTokenAddress,
                paymentTokenId,
                maxTimeDuration,
                pricePerSecond,
                privateRenter
            );

            rentable.createOrUpdateRentalConditions(
                address(testNFT),
                tokenId,
                paymentTokenAddress,
                paymentTokenId,
                maxTimeDuration,
                pricePerSecond,
                privateRenter
            );

            postAssertsUpdateRentalConditions(
                tokenId,
                paymentTokenAddress,
                paymentTokenId,
                maxTimeDuration,
                pricePerSecond,
                privateRenter
            );

            tokenId++;
        }

        cheats.stopPrank();
    }

    function testDeleteRentalConditions() public {
        cheats.startPrank(user);

        uint256 maxTimeDuration = 1000;
        uint256 pricePerSecond = 0.001 ether;

        address paymentTokenAddress = address(0);
        uint256 paymentTokenId = 0;
        address[2] memory privateRenters = [address(0), cheats.addr(5)];
        uint256 tokenId = 123;

        for (uint256 j = 0; j < 2; j++) {
            address privateRenter = privateRenters[j];
            prepareTestDeposit(tokenId);

            rentable.deposit(address(testNFT), tokenId);

            rentable.createOrUpdateRentalConditions(
                address(testNFT),
                tokenId,
                paymentTokenAddress,
                paymentTokenId,
                maxTimeDuration,
                pricePerSecond,
                privateRenter
            );

            rentable.deleteRentalConditions(address(testNFT), tokenId);

            assertEq(
                rentable
                    .rentalConditions(address(testNFT), tokenId)
                    .maxTimeDuration,
                0
            );

            tokenId++;
        }

        cheats.stopPrank();
    }

    function testUpdateRentalConditions() public {
        cheats.startPrank(user);

        uint256 maxTimeDuration = 1000;
        uint256 pricePerSecond = 0.001 ether;

        address paymentTokenAddress = address(0);
        uint256 paymentTokenId = 0;
        address[2] memory privateRenters = [address(0), cheats.addr(5)];
        uint256 tokenId = 123;

        for (uint256 j = 0; j < 2; j++) {
            address privateRenter = privateRenters[j];
            prepareTestDeposit(tokenId);

            rentable.deposit(address(testNFT), tokenId);

            preAssertsUpdateRentalConditions(
                tokenId,
                paymentTokenAddress,
                paymentTokenId,
                maxTimeDuration,
                pricePerSecond,
                privateRenter
            );

            rentable.createOrUpdateRentalConditions(
                address(testNFT),
                tokenId,
                paymentTokenAddress,
                paymentTokenId,
                maxTimeDuration,
                pricePerSecond,
                privateRenter
            );

            postAssertsUpdateRentalConditions(
                tokenId,
                paymentTokenAddress,
                paymentTokenId,
                maxTimeDuration,
                pricePerSecond,
                privateRenter
            );

            //Change rental conditions
            maxTimeDuration = 1000;
            pricePerSecond = 0.001 ether;

            preAssertsUpdateRentalConditions(
                tokenId,
                paymentTokenAddress,
                paymentTokenId,
                maxTimeDuration,
                pricePerSecond,
                privateRenter
            );

            rentable.createOrUpdateRentalConditions(
                address(testNFT),
                tokenId,
                paymentTokenAddress,
                paymentTokenId,
                maxTimeDuration,
                pricePerSecond,
                privateRenter
            );

            postAssertsUpdateRentalConditions(
                tokenId,
                paymentTokenAddress,
                paymentTokenId,
                maxTimeDuration,
                pricePerSecond,
                privateRenter
            );

            tokenId++;
        }

        cheats.stopPrank();
    }
}
