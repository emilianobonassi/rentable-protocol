import brownie
from utils import *


def test_SCRAM(
    testNFT,
    rentable,
    paymentToken,
    paymentTokenId,
    operator,
    weth,
    dummy1155,
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
    pricePerBlock = 0.001 * (10**18)

    rentable.createOrUpdateLeaseConditions(
        testNFT,
        tokenId,
        paymentToken,
        paymentTokenId,
        maxTimeDuration,
        pricePerBlock,
        address0,
        {"from": user},
    )

    rentable.createOrUpdateLeaseConditions(
        testNFT,
        tokenId + 1,
        paymentToken,
        paymentTokenId,
        maxTimeDuration,
        pricePerBlock,
        address0,
        {"from": user},
    )

    subscriptionDuration = 70  # blocks
    value = "0.07 ether"

    depositAndApprove(
        subscriber, rentable, value, paymentToken, paymentTokenId, weth, dummy1155
    )

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
            paymentTokenId,
            maxTimeDuration,
            pricePerBlock,
            address0,
            {"from": user},
        )

    with brownie.reverts("Emergency in place"):
        rentable.deleteLeaseConditions(testNFT, tokenId, {"from": user})

    with brownie.reverts("Emergency in place"):
        rentable.depositAndList(
            testNFT,
            tokenId,
            paymentToken,
            paymentTokenId,
            maxTimeDuration,
            pricePerBlock,
            address0,
            {"from": user},
        )

    with brownie.reverts("Emergency in place"):
        rentable.withdraw(testNFT, tokenId, {"from": user})

    with brownie.reverts("Emergency in place"):
        rentable.expireLease(testNFT, tokenId, {"from": user})

    with brownie.reverts("Emergency in place"):
        rentable.expireLeases([testNFT], [tokenId], {"from": user})

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

    rbalance = getBalance(rentable, paymentToken, paymentTokenId, weth, dummy1155)
    gbalance = getBalance(governance, paymentToken, paymentTokenId, weth, dummy1155)
    if paymentToken == address0 or paymentToken == weth.address:
        rentable.emergencyWithdrawERC20ETH(paymentToken, {"from": governance})
    elif paymentToken == dummy1155.address:
        rentable.emergencyWithdrawERC1155(
            paymentToken, paymentTokenId, {"from": governance}
        )
    assert (
        getBalance(governance, paymentToken, paymentTokenId, weth, dummy1155)
        == gbalance + rbalance
    )
    assert getBalance(rentable, paymentToken, paymentTokenId, weth, dummy1155) == 0
