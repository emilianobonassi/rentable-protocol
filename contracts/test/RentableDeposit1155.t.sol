// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {SharedSetup1155, CheatCodes} from "./SharedSetup1155.t.sol";

import {IRentable1155} from "../IRentable1155.sol";

contract RentableDeposit1155 is SharedSetup1155 {
    function preAssertsTestDeposit(
        uint256 tokenId,
        uint256 amount,
        uint256 oTokenId
    ) internal {
        // Test event emitted
        cheats.expectEmit(true, true, true, true);
        emit Deposit(user, address(testNFT), tokenId, amount, oTokenId);
    }

    function postAssertsTestDeposit(uint256 tokenId, uint256 oTokenId)
        internal
    {
        // Check otokenid <=> tokenid mapping
        assertEq(
            rentable.oTokenIds2tokenIds(address(orentable), oTokenId),
            tokenId
        );

        // Test user ownership
        assertEq(orentable.ownerOf(oTokenId), user);
    }

    function preAssertsTestWithdraw(
        address _user,
        uint256 tokenId,
        uint256 amount,
        uint256 oTokenId
    ) internal {
        // Test event emitted
        cheats.expectEmit(true, true, true, true);
        emit Withdraw(_user, address(testNFT), tokenId, oTokenId, amount);
    }

    function assertBalances(
        address _user,
        uint256 tokenId,
        uint256 oTokenId,
        uint256 amount
    ) internal {
        assertEq(testNFT.balanceOf(address(rentable), tokenId), amount);
        assertEq(
            rentable.user1155Balances(address(testNFT), _user, tokenId),
            amount
        );
        assertEq(
            rentable.oTokenUser1155Balances(address(testNFT), _user, oTokenId),
            amount
        );
    }

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

    function testFirstDeposit() public {
        cheats.startPrank(user);
        /**
            Test deposit with no previous deposit (otokenId = 0)
         */
        uint256 tokenId = 123;
        uint256 oTokenId = 0;

        uint256 mintAmount = 5;
        uint256 depositAmount = 5;

        mint(tokenId, mintAmount);

        preAssertsTestDeposit(tokenId, depositAmount, 1);

        oTokenId = deposit(tokenId, depositAmount, oTokenId);

        postAssertsTestDeposit(tokenId, oTokenId);
        cheats.stopPrank();
    }

    function testWithdraw() public {
        cheats.startPrank(user);
        /**
            Test full withdraw
         */
        uint256 tokenId = 123;
        uint256 oTokenId = 0;

        (uint256 mintAmount, uint256 depositAmount, uint256 withdrawAmount) = (
            5,
            5,
            5
        );

        oTokenId = mintAndDeposit1155(
            tokenId,
            mintAmount,
            depositAmount,
            oTokenId
        );

        preAssertsTestWithdraw(user, tokenId, withdrawAmount, oTokenId);
        rentable.withdraw(address(testNFT), oTokenId, withdrawAmount);

        // Check ownership is on orentable1155
        assertEq(testNFT.balanceOf(address(rentable), tokenId), 0);

        // Check user ownership
        assert(!orentable.exists(oTokenId));
        assertEq(testNFT.balanceOf(user, tokenId), withdrawAmount);

        // Check balances
        assertBalances(user, tokenId, oTokenId, 0);

        cheats.stopPrank();
    }

    function testPartialWithdraw() public {
        cheats.startPrank(user);
        /**
            Test partial withdraw
         */
        uint256 tokenId = 123;
        uint256 oTokenId = 0;

        uint256 mintAmount = 5;
        uint256 depositAmount = 5;
        uint256 withdrawAmount = 3;

        oTokenId = mintAndDeposit1155(
            tokenId,
            mintAmount,
            depositAmount,
            oTokenId
        );

        preAssertsTestWithdraw(user, tokenId, withdrawAmount, oTokenId);
        rentable.withdraw(address(testNFT), oTokenId, withdrawAmount);

        // Check ownership is on orentable1155
        assertEq(
            testNFT.balanceOf(address(rentable), tokenId),
            depositAmount - withdrawAmount
        );

        // Check user ownership
        assert(orentable.exists(oTokenId));
        assertEq(orentable.ownerOf(oTokenId), user);
        assertEq(testNFT.balanceOf(user, tokenId), withdrawAmount);

        // Check balances
        assertBalances(user, tokenId, oTokenId, depositAmount - withdrawAmount);

        cheats.stopPrank();
    }

    function testMultipleDeposit() public {
        cheats.startPrank(user);
        /**
           Test depositing with the same oTokenId
         */
        uint256 tokenId = 123;
        uint256 oTokenId = 0;

        uint256 mintAmount = 5;
        uint256 firstDepositAmount = 3;
        uint256 secondDepositAmount = 2;

        mint(tokenId, mintAmount);

        oTokenId = mintAndDeposit1155(
            tokenId,
            mintAmount,
            firstDepositAmount,
            oTokenId
        );

        preAssertsTestDeposit(tokenId, secondDepositAmount, oTokenId);

        deposit(tokenId, secondDepositAmount, oTokenId);

        postAssertsTestDeposit(tokenId, oTokenId);

        assertBalances(
            user,
            tokenId,
            oTokenId,
            firstDepositAmount + secondDepositAmount
        );

        cheats.stopPrank();
    }

    function testMultipleDepositWrongOtoken() public {
        cheats.startPrank(user);
        /**
            Test deposit with no previous deposit (otokenId = 0)
         */
        uint256 tokenIdA = 123;
        uint256 tokenIdB = 125;
        uint256 oTokenId = 0;

        uint256 mintAmountA = 2;
        uint256 depositAmountA = 1;
        uint256 mintAmountB = 1;
        uint256 depositAmountB = 1;

        mintAndDeposit1155(tokenIdA, mintAmountA, depositAmountA, 0);
        oTokenId = mintAndDeposit1155(tokenIdB, mintAmountB, depositAmountB, 0);

        cheats.expectRevert(bytes("Cannot deposit different tokenId"));
        deposit(tokenIdA, 1, oTokenId);

        cheats.stopPrank();
    }

    function testMultipleDepositWrongOtokenNotYours() public {
        cheats.startPrank(user);
        address anotherUser = cheats.addr(22);
        /**
            Test cannot deposit in a oToken not owned by you
         */
        uint256 tokenIdA = 123;
        uint256 tokenIdB = tokenIdA;
        uint256 oTokenId = 0;

        uint256 mintAmountA = 2;
        uint256 depositAmountA = 1;
        uint256 mintAmountB = 1;
        uint256 depositAmountB = 1;

        mintAndDeposit1155(tokenIdA, mintAmountA, depositAmountA, 0);

        cheats.startPrank(anotherUser);
        testNFT.mint(anotherUser, tokenIdB, mintAmountB);
        testNFT.setApprovalForAll(address(rentable), true);

        oTokenId = deposit(tokenIdB, depositAmountB, 0);
        cheats.stopPrank();
        cheats.startPrank(user);

        cheats.expectRevert(bytes("Otoken must belong to the user"));
        deposit(tokenIdA, 1, oTokenId);

        cheats.stopPrank();
    }

    function testWithdrawNotYours() public {
        cheats.startPrank(user);
        /**
            Test cannot withdraw from a oToken not yours
         */
        uint256 tokenId = 123;
        uint256 oTokenId = 0;

        (uint256 mintAmount, uint256 depositAmount, uint256 withdrawAmount) = (
            5,
            5,
            5
        );

        oTokenId = mintAndDeposit1155(
            tokenId,
            mintAmount,
            depositAmount,
            oTokenId
        );

        cheats.startPrank(cheats.addr(25));
        cheats.expectRevert(bytes("The token must be yours"));
        rentable.withdraw(address(testNFT), oTokenId, withdrawAmount);

        cheats.stopPrank();
    }

    function testCannotDepositZero() public {
        cheats.startPrank(user);
        /**
            Test cannot deposit zero
         */
        uint256 tokenId = 123;
        uint256 oTokenId = 0;

        uint256 mintAmount = 5;
        uint256 depositAmount = 0;

        mint(tokenId, mintAmount);

        cheats.expectRevert(bytes("Cannot deposit 0"));

        oTokenId = deposit(tokenId, depositAmount, oTokenId);

        cheats.stopPrank();
    }

    function testCannotWithdrawZero() public {
        cheats.startPrank(user);
        /**
            Test cannot withdraw zero
         */
        uint256 oTokenId = 0;

        cheats.expectRevert(bytes("Cannot withdraw 0"));

        rentable.withdraw(address(testNFT), oTokenId, 0);

        cheats.stopPrank();
    }

    function testDepositAndTransfer() public {
        cheats.startPrank(user);
        /**
            Test oToken transferability and respective internal structures
         */
        address receiver = cheats.addr(23);
        uint256 tokenId = 123;
        uint256 oTokenId = 0;

        uint256 mintAmount = 5;
        uint256 depositAmount = 5;

        oTokenId = mintAndDeposit1155(
            tokenId,
            mintAmount,
            depositAmount,
            oTokenId
        );

        orentable.safeTransferFrom(user, receiver, oTokenId);

        // Check receiver balances
        assertBalances(receiver, tokenId, oTokenId, depositAmount);

        assertEq(rentable.user1155Balances(address(testNFT), user, tokenId), 0);
        assertEq(
            rentable.oTokenUser1155Balances(address(testNFT), user, oTokenId),
            0
        );

        cheats.stopPrank();
    }

    function testDepositAndSelfTransfer() public {
        cheats.startPrank(user);
        /**
           Test oToken self transferability
         */
        address receiver = user;
        uint256 tokenId = 123;
        uint256 oTokenId = 0;

        uint256 mintAmount = 5;
        uint256 depositAmount = 5;

        oTokenId = mintAndDeposit1155(
            tokenId,
            mintAmount,
            depositAmount,
            oTokenId
        );

        orentable.safeTransferFrom(user, receiver, oTokenId);

        // Check receiver balances
        assertBalances(receiver, tokenId, oTokenId, depositAmount);

        cheats.stopPrank();
    }

    function testDepositAndTransferAndTransfer() public {
        cheats.startPrank(user);
        /**
            Test create two oTokensId and deposit separately, transfering the latter, depositing then
         */
        address receiver = cheats.addr(23);
        uint256 tokenId = 123;
        uint256 oTokenId = 0;

        uint256 mintAmount = 5;
        uint256 depositAmount = 5;

        oTokenId = mintAndDeposit1155(
            tokenId,
            mintAmount,
            depositAmount,
            oTokenId
        );

        orentable.safeTransferFrom(user, receiver, oTokenId);

        cheats.startPrank(receiver);
        testNFT.mint(receiver, tokenId, mintAmount);
        testNFT.setApprovalForAll(address(rentable), true);

        oTokenId = deposit(tokenId, depositAmount, oTokenId);
        cheats.stopPrank();
        cheats.startPrank(user);

        // Check receiver balances
        assertBalances(receiver, tokenId, oTokenId, 2 * depositAmount);

        cheats.stopPrank();
    }

    function testDepositAndTransferAndWithdraw() public {
        cheats.startPrank(user);
        /**
            Test withdraw after transfer
         */
        address receiver = cheats.addr(23);
        uint256 tokenId = 123;
        uint256 oTokenId = 0;

        uint256 mintAmount = 5;
        uint256 depositAmount = 5;

        oTokenId = mintAndDeposit1155(
            tokenId,
            mintAmount,
            depositAmount,
            oTokenId
        );

        orentable.safeTransferFrom(user, receiver, oTokenId);

        cheats.startPrank(receiver);

        preAssertsTestWithdraw(receiver, tokenId, depositAmount, oTokenId);

        rentable.withdraw(address(testNFT), oTokenId, depositAmount);

        // Check ownership is back to the user
        assertEq(testNFT.balanceOf(address(rentable), tokenId), 0);
        assert(!orentable.exists(oTokenId));
        assertEq(testNFT.balanceOf(address(receiver), tokenId), depositAmount);

        // Check receiver balances internal structs
        assertBalances(receiver, tokenId, oTokenId, 0);

        cheats.stopPrank();
    }

    function testDepositAndList() public {
        /**
        Test listing
     */

        cheats.startPrank(user);

        uint256 tokenId = 123;
        uint256 mintAmount = 5;
        uint256 depositAmount = 5;
        uint256 maxTimeDuration = 10000;
        uint256 pricePerBlock = 10;

        testNFT.mint(user, tokenId, mintAmount);
        testNFT.setApprovalForAll(address(rentable), true);

        // Check deposit event
        preAssertsTestDeposit(tokenId, depositAmount, 1);

        preAssertsRentalConditions(
            1,
            address(0),
            0,
            maxTimeDuration,
            pricePerBlock,
            address(0)
        );

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

        assertBalances(user, tokenId, oTokenId, depositAmount);

        // Check user ownership
        assertEq(orentable.ownerOf(oTokenId), user);

        // Check otokenid <=> tokenid mapping
        assertEq(
            rentable.oTokenIds2tokenIds(address(orentable), oTokenId),
            tokenId
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

    function testFirstDeposit1Tx() public {
        cheats.startPrank(user);
        /**
            Test only deposit via 1tx
         */
        uint256 tokenId = 123;

        uint256 mintAmount = 5;
        uint256 depositAmount = 5;

        mint(tokenId, mintAmount);

        preAssertsTestDeposit(tokenId, depositAmount, 1);

        testNFT.safeTransferFrom(
            user,
            address(rentable),
            tokenId,
            depositAmount,
            ""
        );

        postAssertsTestDeposit(tokenId, 1);
        cheats.stopPrank();
    }

    function testMultipleDeposit1Tx() public {
        cheats.startPrank(user);
        /**
           Test only deposit via 1tx multiple steps different oTokenId
         */
        uint256 tokenId = 123;
        uint256 oTokenId = 0;

        uint256 mintAmount = 5;
        uint256 firstDepositAmount = 3;
        uint256 secondDepositAmount = 2;

        mint(tokenId, mintAmount);

        testNFT.safeTransferFrom(
            user,
            address(rentable),
            tokenId,
            firstDepositAmount,
            ""
        );
        oTokenId = 2;
        // Check deposit event
        preAssertsTestDeposit(tokenId, secondDepositAmount, oTokenId);
        testNFT.safeTransferFrom(
            user,
            address(rentable),
            tokenId,
            secondDepositAmount,
            ""
        );

        postAssertsTestDeposit(tokenId, oTokenId);

        // Check ownership is on orentable1155 and balances
        assertEq(testNFT.balanceOf(address(rentable), tokenId), mintAmount);
        assertEq(
            rentable.user1155Balances(address(testNFT), user, tokenId),
            mintAmount
        );
        assertEq(
            rentable.oTokenUser1155Balances(address(testNFT), user, oTokenId),
            secondDepositAmount
        );

        cheats.stopPrank();
    }

    function testFirstDepositAndList1Tx() public {
        cheats.startPrank(user);
        /**
           Test only deposit via 1tx multiple steps different oTokenId
         */
        uint256 tokenId = 123;
        uint256 oTokenId = 0;

        uint256 mintAmount = 5;
        uint256 depositAmount = 5;
        uint256 maxTimeDuration = 10000;
        uint256 pricePerBlock = 10;

        mint(tokenId, mintAmount);

        oTokenId = 1;
        preAssertsTestDeposit(tokenId, depositAmount, oTokenId);

        preAssertsRentalConditions(
            oTokenId,
            address(0),
            0,
            maxTimeDuration,
            pricePerBlock,
            address(0)
        );

        testNFT.safeTransferFrom(
            user,
            address(rentable),
            tokenId,
            depositAmount,
            abi.encode(
                0,
                IRentable1155.RentalConditions({
                    maxTimeDuration: maxTimeDuration,
                    pricePerBlock: pricePerBlock,
                    paymentTokenId: 0,
                    paymentTokenAddress: address(0),
                    privateRenter: address(0)
                })
            )
        );

        // Check deposit event
        postAssertsTestDeposit(tokenId, oTokenId);

        // Check ownership is on orentable1155 and balances
        assertBalances(user, tokenId, oTokenId, depositAmount);

        // Check user ownership
        assertEq(orentable.ownerOf(oTokenId), user);

        // Check otokenid <=> tokenid mapping
        assertEq(
            rentable.oTokenIds2tokenIds(address(orentable), oTokenId),
            tokenId
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

        cheats.stopPrank();
    }

    function testMultipleDepositAndList1Tx() public {
        cheats.startPrank(user);
        /**
           Test only deposit via 1tx multiple steps different oTokenId
         */
        uint256 tokenId = 123;
        uint256 oTokenId = 0;

        uint256 mintAmount = 5;
        uint256 maxTimeDuration = 10000;
        uint256 pricePerBlock = 10;

        mint(tokenId, mintAmount);

        oTokenId = 1;
        uint256 depositAmount = 3;
        preAssertsTestDeposit(tokenId, depositAmount, oTokenId);

        testNFT.safeTransferFrom(
            user,
            address(rentable),
            tokenId,
            depositAmount,
            abi.encode(
                0,
                IRentable1155.RentalConditions({
                    maxTimeDuration: maxTimeDuration,
                    pricePerBlock: pricePerBlock,
                    paymentTokenId: 0,
                    paymentTokenAddress: address(0),
                    privateRenter: address(0)
                })
            )
        );

        preAssertsRentalConditions(
            oTokenId,
            address(0),
            0,
            maxTimeDuration,
            pricePerBlock,
            address(0)
        );

        depositAmount = 2;
        testNFT.safeTransferFrom(
            user,
            address(rentable),
            tokenId,
            depositAmount,
            abi.encode(
                oTokenId,
                IRentable1155.RentalConditions({
                    maxTimeDuration: maxTimeDuration,
                    pricePerBlock: pricePerBlock,
                    paymentTokenId: 0,
                    paymentTokenAddress: address(0),
                    privateRenter: address(0)
                })
            )
        );

        // Check deposit event
        postAssertsTestDeposit(tokenId, oTokenId);

        // Check ownership is on orentable1155 and balances
        assertBalances(user, tokenId, oTokenId, mintAmount);

        // Check user ownership
        assertEq(orentable.ownerOf(oTokenId), user);

        // Check otokenid <=> tokenid mapping
        assertEq(
            rentable.oTokenIds2tokenIds(address(orentable), oTokenId),
            tokenId
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

        cheats.stopPrank();
    }
}
