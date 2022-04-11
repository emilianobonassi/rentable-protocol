// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.7;

import {SharedSetup} from "./SharedSetup.t.sol";

import {ICollectionLibrary} from "../collections/ICollectionLibrary.sol";
import {IRentable} from "../interfaces/IRentable.sol";
import {RentableTypes} from "./../RentableTypes.sol";

contract RentableRent is SharedSetup {
    function testRent()
        public
        payable
        paymentTokensCoverage
        executeByUser(user)
    {
        uint256 maxTimeDuration = 1000;
        uint256 pricePerSecond = 0.001 ether;

        address renter = getNewAddress();
        address privateRenter = address(0);
        prepareTestDeposit();
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

        assertEq(
            rentable.expiresAt(address(testNFT), tokenId),
            block.timestamp + rentalDuration
        );

        uint256 totalFeesToPay = (rentPayed * rentable.getFee()) / 10_000;

        assertEq(
            postBalanceFeeCollector - preBalanceFeeCollector,
            totalFeesToPay
        );

        uint256 renteePayout = preBalanceRenter - postBalanceRenter;

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
        uint256 maxTimeDuration = 10 days;
        uint256 pricePerSecond = 0.001 ether;

        address renter = getNewAddress();
        address privateRenter = renter;

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
        uint256 maxTimeDuration = 1000;
        uint256 pricePerSecond = 0.001 ether;

        address renter = vm.addr(5);
        address privateRenter = address(0);

        prepareTestDeposit();

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

        vm.warp(block.timestamp + rentalDuration + 1);

        rentable.withdraw(address(testNFT), tokenId);

        tokenId++;
    }

    function testTransferWToken() public payable executeByUser(user) {
        uint256 maxTimeDuration = 1000;
        uint256 pricePerSecond = 0.001 ether;

        address renter = vm.addr(5);
        address privateRenter = address(0);

        prepareTestDeposit();

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
        uint256 maxTimeDuration = 1000;
        uint256 pricePerSecond = 0.001 ether;

        address renter = vm.addr(5);
        address privateRenter = address(0);
        prepareTestDeposit();

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
        uint256 maxTimeDuration = 1000;
        uint256 pricePerSecond = 0.001 ether;

        address renter = getNewAddress();
        address privateRenter = address(0);

        prepareTestDeposit();

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
}
