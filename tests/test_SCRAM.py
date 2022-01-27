import brownie


def test_SCRAM(
    testNFT,
    rentable,
    paymentToken,
    operator,
    weth,
    orentable,
    wrentable,
    governance,
    accounts,
    chain,
):
    # 2 subscription, SCRAM, operation stopped, safe withdrawal by governance

    user = accounts[0]
    subscriber = accounts[1]

    tokenId = 123
    testNFT.mint(user, tokenId, {"from": user})
    testNFT.mint(user, tokenId + 1, {"from": user})
    testNFT.mint(user, tokenId + 2, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})
    testNFT.approve(rentable, tokenId + 1, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})
    rentable.deposit(testNFT, tokenId + 1, {"from": user})

    maxTimeDuration = 1000  # 7 days
    pricePerBlock = 0.001 * (10 ** 18)

    rentable.createOrUpdateLeaseConditions(
        testNFT, tokenId, paymentToken, maxTimeDuration, pricePerBlock, {"from": user}
    )

    rentable.createOrUpdateLeaseConditions(
        testNFT,
        tokenId + 1,
        paymentToken,
        maxTimeDuration,
        pricePerBlock,
        {"from": user},
    )

    subscriptionDuration = 70  # blocks
    value = "0.07 ether"

    if paymentToken == weth.address:
        weth.deposit({"from": subscriber, "value": value})
        weth.approve(rentable, value, {"from": subscriber})
        rentable.createLease(
            testNFT, tokenId, subscriptionDuration, {"from": subscriber}
        )
    elif paymentToken == "0x0000000000000000000000000000000000000000":
        rentable.createLease(
            testNFT, tokenId, subscriptionDuration, {"from": subscriber, "value": value}
        )

    rentable.SCRAM({"from": operator})

    assert rentable.paused() == True

    # Test everything fallback on emergency implementation

    with brownie.reverts("Emergency in place"):
        rentable.deposit(testNFT, tokenId, {"from": user})

    with brownie.reverts("Emergency in place"):
        rentable.createOrUpdateLeaseConditions(
            testNFT,
            tokenId,
            paymentToken,
            maxTimeDuration,
            pricePerBlock,
            {"from": user},
        )

    with brownie.reverts("Emergency in place"):
        rentable.deleteLeaseConditions(testNFT, tokenId, {"from": user})

    with brownie.reverts("Emergency in place"):
        rentable.depositAndList(
            testNFT,
            tokenId,
            paymentToken,
            maxTimeDuration,
            pricePerBlock,
            {"from": user},
        )

    with brownie.reverts("Emergency in place"):
        rentable.withdraw(testNFT, tokenId, {"from": user})

    with brownie.reverts("Emergency in place"):
        rentable.redeemLease(1, {"from": user})

    with brownie.reverts("Emergency in place"):
        rentable.expireLease(1, {"from": user})

    with brownie.reverts("Emergency in place"):
        rentable.expireLeases([1], {"from": user})

    with brownie.reverts("Emergency in place"):
        orentable.transferFrom(user, operator, tokenId, {"from": user})

    with brownie.reverts("Emergency in place"):
        wrentable.transferFrom(subscriber, operator, tokenId, {"from": subscriber})

    with brownie.reverts("Emergency in place"):
        testNFT.safeTransferFrom(user, rentable, tokenId + 2, {"from": user})

    # Test safe withdrawal by governance
    # 1. exec emergency operation
    # 2. withdrawal single
    # 3. withdrawal batch

    rentable.emergencyExecute(
        testNFT,
        0,
        testNFT.transferFrom.encode_input(rentable, governance, tokenId),
        False,
        200000,
        {"from": governance},
    )
    assert testNFT.ownerOf(tokenId) == governance.address

    chain.undo()

    rentable.emergencyWithdrawERC721(testNFT, tokenId, True, {"from": governance})
    assert testNFT.ownerOf(tokenId) == governance.address

    chain.undo()

    rentable.emergencyBatchWithdrawERC721(
        testNFT, [tokenId, tokenId + 1], True, {"from": governance}
    )
    assert testNFT.ownerOf(tokenId) == governance.address
    assert testNFT.ownerOf(tokenId + 1) == governance.address

    if paymentToken == weth.address:
        rbalance = weth.balanceOf(rentable)
        rentable.emergencyWithdrawERC20ETH(weth, {"from": governance})
        assert weth.balanceOf(governance) == rbalance
        assert weth.balanceOf(rentable) == 0
    elif paymentToken == "0x0000000000000000000000000000000000000000":
        rbalance = rentable.balance()
        gbalance = governance.balance()
        rentable.emergencyWithdrawERC20ETH(
            "0x0000000000000000000000000000000000000000", {"from": governance}
        )
        assert governance.balance() == gbalance + rbalance
        assert rentable.balance() == 0
