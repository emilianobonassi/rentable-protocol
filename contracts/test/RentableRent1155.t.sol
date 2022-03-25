// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {SharedSetup1155, CheatCodes} from "./SharedSetup1155.t.sol";

import {IRentable1155} from "../IRentable1155.sol";

contract RentableRent1155 is SharedSetup1155 {
    address paymentTokenAddress = address(0);
    uint256 paymentTokenId = 0;
    uint256 tokenId = 123;
    address renter = cheats.addr(7);

    function getBalance(
        address user,
        address paymentToken,
        uint256 _paymentTokenId
    ) public view returns (uint256) {
        if (paymentToken == address(weth)) {
            return weth.balanceOf(user);
        } else if (paymentToken == address(dummy1155)) {
            return dummy1155.balanceOf(user, _paymentTokenId);
        } else {
            return user.balance;
        }
    }

    function depositAndApprove(
        address _user,
        uint256 value,
        address _paymentToken,
        uint256 _paymentTokenId
    ) public override {
        cheats.deal(_user, value);
        if (_paymentToken == address(weth)) {
            weth.deposit{value: value}();
            weth.approve(address(rentable), ~uint256(0));
        } else if (_paymentToken == address(dummy1155)) {
            dummy1155.deposit{value: value}(_paymentTokenId);
            dummy1155.setApprovalForAll(address(rentable), true);
        }
    }

    function preAssertRental(
        address _from,
        address _to,
        uint256 oTokenId,
        uint256 wTokenId
    ) public {
        cheats.expectEmit(true, true, true, true);
        emit Rent(_from, _to, address(testNFT), oTokenId, wTokenId);
    }

    function testRent() public {
        /**
        Test listing
     */

        cheats.startPrank(user);
        uint256 maxTimeDuration = 10000;
        uint256 pricePerBlock = 10;
        uint256 rentAmount = 5;

        testNFT.mint(user, tokenId, 5);
        testNFT.setApprovalForAll(address(rentable), true);

        uint256 oTokenId = rentable.depositAndList(
            address(testNFT),
            tokenId,
            5,
            0,
            address(0),
            0,
            maxTimeDuration,
            pricePerBlock,
            address(0)
        );
        cheats.stopPrank();
        cheats.startPrank(renter);
        uint256 rentalDuration = 70;
        uint256 value = 0.07 ether * rentAmount;

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

        preAssertRental(user, renter, 1, 1);

        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            oTokenId,
            rentalDuration,
            rentAmount
        );

        cheats.stopPrank();
        cheats.startPrank(user);

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

        assertEq(rentPayed, pricePerBlock * rentalDuration * rentAmount);

        IRentable1155.Rental memory r = rentable.rentals(address(wrentable), 1);

        assertEq(r.eta, block.number + rentalDuration);
        assertEq(r.amount, rentAmount);

        uint256 totalFeesToPay = (
            (((rentPayed - rentable.fixedFee()) * rentable.fee()) /
                rentable.BASE_FEE())
        ) + rentable.fixedFee();

        assertEq(
            postBalanceFeeCollector - preBalanceFeeCollector,
            totalFeesToPay
        );

        uint256 renteePayout = preBalanceRenter - postBalanceRenter;

        assertEq(postBalanceUser - preBalanceUser, renteePayout);

        assertEq(wrentable.ownerOf(1), renter);

        cheats.expectRevert(
            bytes("Amount required not available, busy on rental")
        );
        rentable.withdraw(address(testNFT), oTokenId, 5);

        cheats.roll(rentalDuration + 1);
        assertEq(wrentable.ownerOf(1), address(0));

        rentable.withdraw(address(testNFT), oTokenId, 5);
    }

    function testRentPrivate() public {
        /**
       Test rental by private user
     */

        cheats.startPrank(user);
        address privateRenter = cheats.addr(26);
        uint256 maxTimeDuration = 10000;
        uint256 pricePerBlock = 10;
        uint256 rentAmount = 5;

        testNFT.mint(user, tokenId, 5);
        testNFT.setApprovalForAll(address(rentable), true);

        uint256 oTokenId = rentable.depositAndList(
            address(testNFT),
            tokenId,
            5,
            0,
            address(0),
            0,
            maxTimeDuration,
            pricePerBlock,
            privateRenter
        );
        cheats.stopPrank();
        cheats.startPrank(renter);
        uint256 rentalDuration = 70;
        uint256 value = 0.07 ether * rentAmount;

        depositAndApprove(renter, value, paymentTokenAddress, paymentTokenId);
        depositAndApprove(
            privateRenter,
            value,
            paymentTokenAddress,
            paymentTokenId
        );

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

        cheats.expectRevert(bytes("Rental reserved for another user"));
        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            oTokenId,
            rentalDuration,
            rentAmount
        );
        cheats.stopPrank();
        cheats.startPrank(privateRenter);
        renter = privateRenter;
        preAssertRental(user, renter, 1, 1);

        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            oTokenId,
            rentalDuration,
            rentAmount
        );

        cheats.stopPrank();
        cheats.startPrank(user);

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

        assertEq(rentPayed, pricePerBlock * rentalDuration * rentAmount);

        IRentable1155.Rental memory r = rentable.rentals(address(wrentable), 1);

        assertEq(r.eta, block.number + rentalDuration);
        assertEq(r.amount, rentAmount);

        uint256 totalFeesToPay = (
            (((rentPayed - rentable.fixedFee()) * rentable.fee()) /
                rentable.BASE_FEE())
        ) + rentable.fixedFee();

        assertEq(
            postBalanceFeeCollector - preBalanceFeeCollector,
            totalFeesToPay
        );

        uint256 renteePayout = preBalanceRenter - postBalanceRenter;

        assertEq(postBalanceUser - preBalanceUser, renteePayout);

        assertEq(wrentable.ownerOf(1), renter);

        cheats.expectRevert(
            bytes("Amount required not available, busy on rental")
        );
        rentable.withdraw(address(testNFT), oTokenId, 5);

        cheats.roll(rentalDuration + 1);
        assertEq(wrentable.ownerOf(1), address(0));

        rentable.withdraw(address(testNFT), oTokenId, 5);
    }

    function testCannotRentOverAmountOrDuration() public {
        /**
        Test listing
     */

        cheats.startPrank(user);
        uint256 maxTimeDuration = 10000;
        uint256 pricePerBlock = 10;
        uint256 rentAmount = 5;

        testNFT.mint(user, tokenId, 5);
        testNFT.setApprovalForAll(address(rentable), true);

        uint256 oTokenId = rentable.depositAndList(
            address(testNFT),
            tokenId,
            5,
            0,
            address(0),
            0,
            maxTimeDuration,
            pricePerBlock,
            address(0)
        );

        cheats.stopPrank();
        cheats.startPrank(renter);
        uint256 rentalDuration = 70;
        uint256 value = 0.07 ether * rentAmount;

        depositAndApprove(renter, value, paymentTokenAddress, paymentTokenId);

        cheats.expectRevert("Amount required not available");
        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            oTokenId,
            rentalDuration,
            rentAmount + 1
        );

        cheats.expectRevert("Duration greater than conditions");
        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            oTokenId,
            maxTimeDuration + 1,
            rentAmount
        );
    }

    function testDoubleRent() public {
        /**
        Test multiple rent same oTokenId
     */

        cheats.startPrank(user);
        uint256 maxTimeDuration = 10000;
        uint256 pricePerBlock = 10;
        uint256 rentAmount = 5;

        testNFT.mint(user, tokenId, 5);
        testNFT.setApprovalForAll(address(rentable), true);

        uint256 oTokenId = rentable.depositAndList(
            address(testNFT),
            tokenId,
            5,
            0,
            address(0),
            0,
            maxTimeDuration,
            pricePerBlock,
            address(0)
        );

        cheats.stopPrank();
        cheats.startPrank(renter);
        uint256 rentalDuration = 70;
        uint256 value = 0.07 ether * (rentAmount + 1);

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

        preAssertRental(user, renter, 1, 1);

        rentable.rent{
            value: paymentTokenAddress == address(0) ? 0.07 ether * 3 : 0
        }(address(testNFT), oTokenId, rentalDuration, 3);

        cheats.expectRevert(bytes("Amount required not available"));
        rentable.rent{
            value: paymentTokenAddress == address(0) ? 0.07 ether * 3 : 0
        }(address(testNFT), oTokenId, rentalDuration, 3);

        rentable.rent{
            value: paymentTokenAddress == address(0) ? 0.07 ether * 2 : 0
        }(address(testNFT), oTokenId, rentalDuration, 2);

        cheats.stopPrank();
        cheats.startPrank(user);

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

        assertEq(rentPayed, pricePerBlock * rentalDuration * rentAmount);

        IRentable1155.Rental memory r = rentable.rentals(address(wrentable), 2);

        assertEq(r.eta, block.number + rentalDuration);
        assertEq(r.amount, 2);

        uint256 totalFeesToPay = (
            (((rentPayed - rentable.fixedFee()) * rentable.fee()) /
                rentable.BASE_FEE())
        ) + rentable.fixedFee();

        assertEq(
            postBalanceFeeCollector - preBalanceFeeCollector,
            totalFeesToPay
        );

        uint256 renteePayout = preBalanceRenter - postBalanceRenter;

        assertEq(postBalanceUser - preBalanceUser, renteePayout);

        assertEq(wrentable.ownerOf(1), renter);
    }

    function testRentAfterExpire() public {
        /**
        Test rent possible after expire
     */

        cheats.startPrank(user);
        uint256 maxTimeDuration = 10000;
        uint256 pricePerBlock = 10;
        uint256 rentAmount = 5;

        testNFT.mint(user, tokenId, 5);
        testNFT.setApprovalForAll(address(rentable), true);

        uint256 oTokenId = rentable.depositAndList(
            address(testNFT),
            tokenId,
            5,
            0,
            address(0),
            0,
            maxTimeDuration,
            pricePerBlock,
            address(0)
        );
        cheats.stopPrank();
        cheats.startPrank(renter);
        uint256 rentalDuration = 70;
        uint256 value = 0.07 ether * (2 * rentAmount);

        depositAndApprove(renter, value, paymentTokenAddress, paymentTokenId);

        rentable.rent{
            value: paymentTokenAddress == address(0) ? 0.07 ether * 5 : 0
        }(address(testNFT), oTokenId, rentalDuration, 5);

        cheats.roll(block.number + rentalDuration + 1);

        cheats.expectEmit(true, true, true, true);
        emit RentEnds(address(wrentable), 1);

        rentable.rent{
            value: paymentTokenAddress == address(0) ? 0.07 ether * 5 : 0
        }(address(testNFT), oTokenId, rentalDuration, 5);
    }

    function testWithdrawAfterExpire() public {
        /**
        Test rent possible after expire
     */

        cheats.startPrank(user);
        uint256 maxTimeDuration = 10000;
        uint256 pricePerBlock = 10;
        uint256 rentAmount = 5;

        testNFT.mint(user, tokenId, 5);
        testNFT.setApprovalForAll(address(rentable), true);

        uint256 oTokenId = rentable.depositAndList(
            address(testNFT),
            tokenId,
            5,
            0,
            address(0),
            0,
            maxTimeDuration,
            pricePerBlock,
            address(0)
        );
        cheats.stopPrank();
        cheats.startPrank(renter);
        uint256 rentalDuration = 70;
        uint256 value = 0.07 ether * (2 * rentAmount);

        depositAndApprove(renter, value, paymentTokenAddress, paymentTokenId);

        rentable.rent{
            value: paymentTokenAddress == address(0) ? 0.07 ether * 5 : 0
        }(address(testNFT), oTokenId, rentalDuration, 5);

        cheats.roll(block.number + rentalDuration + 1);

        cheats.expectEmit(true, true, true, true);
        emit RentEnds(address(wrentable), 1);
        cheats.stopPrank();
        cheats.startPrank(user);
        rentable.withdraw(address(testNFT), oTokenId, 5);
    }

    function testExpire() public {
        /**
        Test rent possible after expire
     */

        cheats.startPrank(user);
        uint256 maxTimeDuration = 10000;
        uint256 pricePerBlock = 10;
        uint256 rentAmount = 5;

        testNFT.mint(user, tokenId, 5);
        testNFT.setApprovalForAll(address(rentable), true);

        uint256 oTokenId = rentable.depositAndList(
            address(testNFT),
            tokenId,
            5,
            0,
            address(0),
            0,
            maxTimeDuration,
            pricePerBlock,
            address(0)
        );

        cheats.stopPrank();
        cheats.startPrank(renter);
        uint256 rentalDuration = 70;
        uint256 value = 0.07 ether * (rentAmount);

        depositAndApprove(renter, value, paymentTokenAddress, paymentTokenId);

        rentable.rent{
            value: paymentTokenAddress == address(0) ? 0.07 ether * 3 : 0
        }(address(testNFT), oTokenId, rentalDuration, 3);

        rentable.rent{
            value: paymentTokenAddress == address(0) ? 0.07 ether * 2 : 0
        }(address(testNFT), oTokenId, rentalDuration, 2);

        cheats.roll(block.number + rentalDuration + 1);

        cheats.expectEmit(true, true, true, true);
        emit RentEnds(address(wrentable), 1);
        emit RentEnds(address(wrentable), 2);

        address[] memory wtokens = new address[](2);
        wtokens[0] = address(wrentable);
        wtokens[1] = address(wrentable);

        address[] memory tokens = new address[](2);
        tokens[0] = address(testNFT);
        tokens[1] = address(testNFT);

        uint256[] memory oids = new uint256[](2);
        oids[0] = 1;
        oids[1] = 1;

        rentable.expireRentals(wtokens, tokens, oids);
    }
}
