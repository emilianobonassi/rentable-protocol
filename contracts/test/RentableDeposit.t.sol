// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.7;

import {SharedSetup} from "./SharedSetup.t.sol";

import {ICollectionLibrary} from "../collections/ICollectionLibrary.sol";
import {IRentable} from "../interfaces/IRentable.sol";

import {RentableTypes} from "./../RentableTypes.sol";

contract RentableTest is SharedSetup {
    function preAssertsTestDeposit(uint256 tokenId) internal {
        // Test event emitted
        vm.expectEmit(true, true, true, true);
        emit Deposit(user, address(testNFT), tokenId);

        // Test dummy library
        bytes memory expectedData = abi.encodeWithSelector(
            ICollectionLibrary.postDeposit.selector,
            address(testNFT),
            tokenId,
            user
        );
        vm.expectCall(address(dummyLib), expectedData);
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
        vm.expectEmit(true, true, true, true);

        emit UpdateRentalConditions(
            address(testNFT),
            tokenId,
            paymentTokenAddress,
            paymentTokenId,
            maxTimeDuration,
            pricePerSecond,
            privateRenter
        );

        bytes memory expectedData = abi.encodeWithSelector(
            ICollectionLibrary.postList.selector,
            address(testNFT),
            tokenId,
            user,
            maxTimeDuration,
            pricePerSecond
        );
        vm.expectCall(address(dummyLib), expectedData);
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

    function testDeposit() public executeByUser(user) {
        prepareTestDeposit();

        testNFT.safeTransferFrom(user, address(rentable), tokenId);

        postAssertsTestDeposit(tokenId);
    }

    function testDepositAndList()
        public
        privateRentersCoverage
        paymentTokensCoverage
        executeByUser(user)
    {
        uint256 maxTimeDuration = 10 days;
        uint256 pricePerSecond = 0.001 ether;

        prepareTestDeposit();

        preAssertsTestDeposit(tokenId);
        preAssertsUpdateRentalConditions(
            tokenId,
            paymentTokenAddress,
            paymentTokenId,
            maxTimeDuration,
            pricePerSecond,
            privateRenter
        );

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

        postAssertsTestDeposit(tokenId);

        postAssertsUpdateRentalConditions(
            tokenId,
            paymentTokenAddress,
            paymentTokenId,
            maxTimeDuration,
            pricePerSecond,
            privateRenter
        );
    }

    function testDepositAndListWrongPaymentToken() public executeByUser(user) {
        prepareTestDeposit();
        vm.expectRevert(bytes("Not supported payment token"));
        testNFT.safeTransferFrom(
            user,
            address(rentable),
            tokenId,
            abi.encode(
                RentableTypes.RentalConditions({
                    maxTimeDuration: 10 days,
                    pricePerSecond: 0.001 ether,
                    paymentTokenId: 0,
                    paymentTokenAddress: getNewAddress(),
                    privateRenter: address(0)
                })
            )
        );
    }

    function testWithdraw() public executeByUser(user) {
        prepareTestDeposit();
        testNFT.safeTransferFrom(user, address(rentable), tokenId);

        vm.expectEmit(true, true, true, true);
        emit Withdraw(address(testNFT), tokenId);

        rentable.withdraw(address(testNFT), tokenId);

        vm.expectRevert(bytes("ERC721: owner query for nonexistent token"));

        orentable.ownerOf(tokenId);

        assertEq(testNFT.ownerOf(tokenId), user);
    }

    function testCreateRentalConditions()
        public
        privateRentersCoverage
        paymentTokensCoverage
        executeByUser(user)
    {
        uint256 maxTimeDuration = 10 days;
        uint256 pricePerSecond = 0.001 ether;

        prepareTestDeposit();

        testNFT.safeTransferFrom(user, address(rentable), tokenId);

        preAssertsUpdateRentalConditions(
            tokenId,
            paymentTokenAddress,
            paymentTokenId,
            maxTimeDuration,
            pricePerSecond,
            privateRenter
        );

        RentableTypes.RentalConditions memory rc = RentableTypes
            .RentalConditions({
                paymentTokenAddress: paymentTokenAddress,
                paymentTokenId: paymentTokenId,
                maxTimeDuration: maxTimeDuration,
                pricePerSecond: pricePerSecond,
                privateRenter: privateRenter
            });

        rentable.createOrUpdateRentalConditions(address(testNFT), tokenId, rc);

        postAssertsUpdateRentalConditions(
            tokenId,
            paymentTokenAddress,
            paymentTokenId,
            maxTimeDuration,
            pricePerSecond,
            privateRenter
        );
    }

    function testCreateRentalConditionsWrongPaymentToken()
        public
        executeByUser(user)
    {
        prepareTestDeposit();

        testNFT.safeTransferFrom(user, address(rentable), tokenId);

        RentableTypes.RentalConditions memory rc = RentableTypes
            .RentalConditions({
                paymentTokenAddress: getNewAddress(),
                paymentTokenId: 0,
                maxTimeDuration: 10 days,
                pricePerSecond: 0.001 ether,
                privateRenter: address(0)
            });

        vm.expectRevert(bytes("Not supported payment token"));
        rentable.createOrUpdateRentalConditions(address(testNFT), tokenId, rc);
    }

    function testDeleteRentalConditions() public executeByUser(user) {
        prepareTestDeposit();

        testNFT.safeTransferFrom(user, address(rentable), tokenId);

        RentableTypes.RentalConditions memory rc = RentableTypes
            .RentalConditions({
                paymentTokenAddress: address(0),
                paymentTokenId: 0,
                maxTimeDuration: 10 days,
                pricePerSecond: 0.001 ether,
                privateRenter: address(0)
            });

        rentable.createOrUpdateRentalConditions(address(testNFT), tokenId, rc);

        rentable.deleteRentalConditions(address(testNFT), tokenId);

        assertEq(
            rentable
                .rentalConditions(address(testNFT), tokenId)
                .maxTimeDuration,
            0
        );
    }

    function testUpdateRentalConditions() public executeByUser(user) {
        uint256 maxTimeDuration = 1000;
        uint256 pricePerSecond = 0.001 ether;

        address paymentTokenAddress = address(0);
        uint256 paymentTokenId = 0;
        address[2] memory privateRenters = [address(0), vm.addr(5)];

        for (uint256 j = 0; j < 2; j++) {
            address privateRenter = privateRenters[j];
            prepareTestDeposit();

            testNFT.safeTransferFrom(user, address(rentable), tokenId);

            preAssertsUpdateRentalConditions(
                tokenId,
                paymentTokenAddress,
                paymentTokenId,
                maxTimeDuration,
                pricePerSecond,
                privateRenter
            );

            RentableTypes.RentalConditions memory rc = RentableTypes
                .RentalConditions({
                    paymentTokenAddress: paymentTokenAddress,
                    paymentTokenId: paymentTokenId,
                    maxTimeDuration: maxTimeDuration,
                    pricePerSecond: pricePerSecond,
                    privateRenter: privateRenter
                });

            rentable.createOrUpdateRentalConditions(
                address(testNFT),
                tokenId,
                rc
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

            rc = RentableTypes.RentalConditions({
                paymentTokenAddress: paymentTokenAddress,
                paymentTokenId: paymentTokenId,
                maxTimeDuration: maxTimeDuration,
                pricePerSecond: pricePerSecond,
                privateRenter: privateRenter
            });

            rentable.createOrUpdateRentalConditions(
                address(testNFT),
                tokenId,
                rc
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
    }
}
