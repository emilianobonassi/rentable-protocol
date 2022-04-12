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

    function _testRentalConditions(
        uint256 _tokenId,
        address _paymentTokenAddress,
        uint256 _paymentTokenId,
        uint256 _maxTimeDuration,
        uint256 _pricePerSecond,
        address _privateRenter
    ) internal {
        preAssertsUpdateRentalConditions(
            _tokenId,
            _paymentTokenAddress,
            _paymentTokenId,
            _maxTimeDuration,
            _pricePerSecond,
            _privateRenter
        );

        RentableTypes.RentalConditions memory rc = RentableTypes
            .RentalConditions({
                paymentTokenAddress: _paymentTokenAddress,
                paymentTokenId: _paymentTokenId,
                maxTimeDuration: _maxTimeDuration,
                pricePerSecond: _pricePerSecond,
                privateRenter: _privateRenter
            });

        rentable.createOrUpdateRentalConditions(address(testNFT), _tokenId, rc);

        postAssertsUpdateRentalConditions(
            _tokenId,
            _paymentTokenAddress,
            _paymentTokenId,
            _maxTimeDuration,
            _pricePerSecond,
            _privateRenter
        );
    }

    function testUpdateRentalConditions() public executeByUser(user) {
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

        //Change rental conditions field by field

        // PaymentTokenAddress
        _testRentalConditions(
            tokenId,
            address(dummy1155),
            paymentTokenId,
            maxTimeDuration,
            pricePerSecond,
            privateRenter
        );

        // PaymentTokenId
        _testRentalConditions(
            tokenId,
            paymentTokenAddress,
            paymentTokenId + 1,
            maxTimeDuration,
            pricePerSecond,
            privateRenter
        );

        // MaxDuration
        _testRentalConditions(
            tokenId,
            paymentTokenAddress,
            paymentTokenId,
            maxTimeDuration + 2 days,
            pricePerSecond,
            privateRenter
        );

        // PricePerSecond
        _testRentalConditions(
            tokenId,
            paymentTokenAddress,
            paymentTokenId,
            maxTimeDuration,
            pricePerSecond + 0.05 ether,
            privateRenter
        );

        // PrivateRenter
        _testRentalConditions(
            tokenId,
            paymentTokenAddress,
            paymentTokenId,
            maxTimeDuration,
            pricePerSecond,
            getNewAddress()
        );
    }
}
