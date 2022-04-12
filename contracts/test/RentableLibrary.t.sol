// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.7;

import {SharedSetup} from "./SharedSetup.t.sol";

import {ICollectionLibrary} from "../collections/ICollectionLibrary.sol";

import {RentableTypes} from "./../RentableTypes.sol";

contract RentableLibrary is SharedSetup {
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

        address receiver = getNewAddress();

        bytes memory expectedData = abi.encodeWithSelector(
            ICollectionLibrary.postWTokenTransfer.selector,
            address(testNFT),
            tokenId,
            renter,
            receiver
        );
        vm.expectCall(address(dummyLib), expectedData);

        wrentable.transferFrom(renter, receiver, tokenId);

        assertEq(wrentable.ownerOf(tokenId), receiver);
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

        address receiver = getNewAddress();

        bytes memory expectedData = abi.encodeWithSelector(
            ICollectionLibrary.postOTokenTransfer.selector,
            address(testNFT),
            tokenId,
            user,
            receiver,
            true
        );
        vm.expectCall(address(dummyLib), expectedData);

        orentable.transferFrom(user, receiver, tokenId);

        assertEq(orentable.ownerOf(tokenId), receiver);
    }

    function testPostList() public executeByUser(user) {
        prepareTestDeposit();

        bytes memory expectedData = abi.encodeWithSelector(
            ICollectionLibrary.postDeposit.selector,
            address(testNFT),
            tokenId,
            user
        );
        vm.expectCall(address(dummyLib), expectedData);

        testNFT.safeTransferFrom(user, address(rentable), tokenId);
    }

    function testPostDeposit() public executeByUser(user) {
        minTimeDuration = 0;
        maxTimeDuration = 10 days;
        pricePerSecond = 0.001 ether;

        renter = getNewAddress();
        prepareTestDeposit();

        bytes memory expectedData = abi.encodeWithSelector(
            ICollectionLibrary.postList.selector,
            address(testNFT),
            tokenId,
            user,
            minTimeDuration,
            maxTimeDuration,
            pricePerSecond
        );
        vm.expectCall(address(dummyLib), expectedData);

        testNFT.safeTransferFrom(
            user,
            address(rentable),
            tokenId,
            abi.encode(
                RentableTypes.RentalConditions({
                    minTimeDuration: minTimeDuration,
                    maxTimeDuration: maxTimeDuration,
                    pricePerSecond: pricePerSecond,
                    paymentTokenId: paymentTokenId,
                    paymentTokenAddress: paymentTokenAddress,
                    privateRenter: privateRenter
                })
            )
        );
    }
}
