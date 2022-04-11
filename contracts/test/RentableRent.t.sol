// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.7;

import {SharedSetup} from "./SharedSetup.t.sol";

import {ICollectionLibrary} from "../collections/ICollectionLibrary.sol";
import {IRentable} from "../interfaces/IRentable.sol";
import {RentableTypes} from "./../RentableTypes.sol";

contract RentableRent is SharedSetup {
    uint256 pricePerSecond;
    uint256 maxTimeDuration;
    address renter;

    function _prepareRent() internal {
        _prepareRent(getNewAddress());
    }

    function _prepareRent(address _renter) internal {
        maxTimeDuration = 10 days;
        pricePerSecond = 0.001 ether;

        renter = _renter;
        prepareTestDeposit();

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

    function testRent()
        public
        payable
        protocolFeeCoverage
        paymentTokensCoverage
        executeByUser(user)
    {
        _prepareRent();

        uint256 rentalDuration = 80;
        uint256 value = 0.08 ether;

        // Test event emitted
        vm.expectEmit(true, true, true, true);

        emit Rent(
            user,
            renter,
            address(testNFT),
            tokenId,
            paymentTokenAddress,
            paymentTokenId,
            block.timestamp + rentalDuration
        );

        switchUser(renter);
        depositAndApprove(renter, value, paymentTokenAddress, paymentTokenId);

        uint256 preBalanceUser = getBalance(
            user,
            paymentTokenAddress,
            paymentTokenId
        );
        uint256 preBalanceFeeCollector = getBalance(
            feeCollector,
            paymentTokenAddress,
            paymentTokenId
        );
        uint256 preBalanceRenter = getBalance(
            renter,
            paymentTokenAddress,
            paymentTokenId
        );

        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            tokenId,
            rentalDuration
        );

        switchUser(user);

        uint256 postBalanceUser = getBalance(
            user,
            paymentTokenAddress,
            paymentTokenId
        );
        uint256 postBalanceFeeCollector = getBalance(
            feeCollector,
            paymentTokenAddress,
            paymentTokenId
        );
        uint256 postBalanceRenter = getBalance(
            renter,
            paymentTokenAddress,
            paymentTokenId
        );

        uint256 rentPayed = preBalanceRenter - postBalanceRenter;

        assertEq(rentPayed, rentalDuration * pricePerSecond);

        assertEq(
            rentable.expiresAt(address(testNFT), tokenId),
            block.timestamp + rentalDuration
        );

        uint256 totalFeesToPay = (rentPayed * rentable.getFee()) / 10_000;

        assertEq(
            postBalanceFeeCollector - preBalanceFeeCollector,
            totalFeesToPay
        );

        uint256 renteePayout = rentPayed - totalFeesToPay;

        assertEq(postBalanceUser - preBalanceUser, renteePayout);

        assertEq(wrentable.ownerOf(tokenId), renter);

        vm.warp(block.timestamp + rentalDuration + 1);

        assertEq(wrentable.ownerOf(tokenId), address(0));

        // Test event emitted
        vm.expectEmit(true, true, true, true);
        emit RentEnds(address(testNFT), tokenId);

        rentable.expireRental(address(testNFT), tokenId);
    }

    function testRentPrivate() public payable executeByUser(user) {
        renter = getNewAddress();
        privateRenter = renter;
        _prepareRent(renter);

        uint256 rentalDuration = 80;
        uint256 value = 0.08 ether;

        switchUser(renter);
        depositAndApprove(renter, value, paymentTokenAddress, paymentTokenId);

        address wrongRenter = getNewAddress();
        switchUser(wrongRenter);
        depositAndApprove(
            wrongRenter,
            value,
            paymentTokenAddress,
            paymentTokenId
        );
        vm.expectRevert(bytes("Rental reserved for another user"));
        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            tokenId,
            rentalDuration
        );

        switchUser(renter);

        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            tokenId,
            rentalDuration
        );
    }

    function testCannotWithdrawOnRent() public payable executeByUser(user) {
        _prepareRent();

        uint256 rentalDuration = 80;
        uint256 value = 0.08 ether;

        switchUser(renter);
        depositAndApprove(renter, value, paymentTokenAddress, paymentTokenId);

        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            tokenId,
            rentalDuration
        );

        switchUser(user);

        vm.expectRevert(bytes("Current rent still pending"));
        rentable.withdraw(address(testNFT), tokenId);
    }

    function testCannotRentOnRent() public payable executeByUser(user) {
        _prepareRent();

        uint256 rentalDuration = 80;
        uint256 value = 0.08 ether;

        switchUser(renter);
        depositAndApprove(renter, value, paymentTokenAddress, paymentTokenId);

        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            tokenId,
            rentalDuration
        );

        address anotherRenter = getNewAddress();
        switchUser(anotherRenter);
        depositAndApprove(
            anotherRenter,
            value,
            paymentTokenAddress,
            paymentTokenId
        );

        vm.expectRevert(bytes("Current rent still pending"));

        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            tokenId,
            rentalDuration
        );
    }

    function testCannotRentMoreThanAllowed()
        public
        payable
        executeByUser(user)
    {
        _prepareRent();

        uint256 rentalDuration = maxTimeDuration + 1 days;
        uint256 value = rentalDuration * pricePerSecond;

        switchUser(renter);
        depositAndApprove(renter, value, paymentTokenAddress, paymentTokenId);

        vm.expectRevert(bytes("Duration greater than conditions"));
        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            tokenId,
            rentalDuration
        );
    }

    function testTransferWToken() public payable executeByUser(user) {
        _prepareRent();

        uint256 rentalDuration = 80;
        uint256 value = 0.08 ether;

        switchUser(renter);
        depositAndApprove(renter, value, paymentTokenAddress, paymentTokenId);

        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            tokenId,
            rentalDuration
        );

        bytes memory expectedData = abi.encodeWithSelector(
            ICollectionLibrary.postWTokenTransfer.selector,
            address(testNFT),
            tokenId,
            renter,
            vm.addr(9)
        );
        vm.expectCall(address(dummyLib), expectedData);

        wrentable.transferFrom(renter, vm.addr(9), tokenId);

        assertEq(wrentable.ownerOf(tokenId), vm.addr(9));
    }

    function testTransferOToken() public payable executeByUser(user) {
        _prepareRent();

        uint256 rentalDuration = 80;
        uint256 value = 0.08 ether;

        switchUser(renter);
        depositAndApprove(renter, value, paymentTokenAddress, paymentTokenId);

        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            tokenId,
            rentalDuration
        );
        switchUser(user);

        bytes memory expectedData = abi.encodeWithSelector(
            ICollectionLibrary.postOTokenTransfer.selector,
            address(testNFT),
            tokenId,
            user,
            vm.addr(9),
            true
        );
        vm.expectCall(address(dummyLib), expectedData);

        orentable.transferFrom(user, vm.addr(9), tokenId);

        assertEq(orentable.ownerOf(tokenId), vm.addr(9));
    }

    function testRentAfterExpire() public payable executeByUser(user) {
        _prepareRent();

        uint256 rentalDuration = 80;
        uint256 value = 0.08 ether;

        switchUser(renter);
        depositAndApprove(renter, value, paymentTokenAddress, paymentTokenId);

        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            tokenId,
            rentalDuration
        );

        vm.warp(block.timestamp + rentalDuration + 1);

        depositAndApprove(renter, value, paymentTokenAddress, paymentTokenId);

        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            tokenId,
            rentalDuration
        );
    }

    function testWithdrawAfterExpire() public payable executeByUser(user) {
        _prepareRent();

        uint256 rentalDuration = 80;
        uint256 value = 0.08 ether;

        switchUser(renter);
        depositAndApprove(renter, value, paymentTokenAddress, paymentTokenId);

        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            tokenId,
            rentalDuration
        );

        vm.warp(block.timestamp + rentalDuration + 1);

        switchUser(user);
        rentable.withdraw(address(testNFT), tokenId);
    }
}
