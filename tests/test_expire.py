import brownie
from utils import *


def test_redeem_after_expire(
    rentable,
    testNFT,
    paymentToken,
    paymentTokenId,
    accounts,
    chain,
    weth,
    dummy1155,
    dummylib,
):
    rentable.setLibrary(testNFT, dummylib)
    assert rentable.getLibrary(testNFT) == dummylib

    user = accounts[0]
    subscriber = accounts[1]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})

    maxTimeDuration = 1000  # 7 days
    pricePerBlock = 0.01 * (10**18)

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

    # Test subscribtion
    subscriptionDuration = 10  # blocks
    value = "0.1 ether"

    depositAndApprove(
        subscriber, rentable, value, paymentToken, paymentTokenId, weth, dummy1155
    )

    rentable.createLease(
        testNFT, tokenId, subscriptionDuration, {"from": subscriber, "value": value}
    )

    leaseId = 1

    chain.mine(5)

    with brownie.reverts("Current lease still pending"):
        rentable.expireLeases([leaseId])

    chain.mine(6)

    rentable.expireLeases([leaseId])

    rentable.redeemLease(leaseId, {"from": user})


def test_subscribe_after_expire(
    rentable,
    testNFT,
    paymentToken,
    paymentTokenId,
    accounts,
    chain,
    weth,
    dummy1155,
    dummylib,
):
    rentable.setLibrary(testNFT, dummylib)
    assert rentable.getLibrary(testNFT) == dummylib

    user = accounts[0]
    subscriber = accounts[1]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})

    maxTimeDuration = 1000  # 7 days
    pricePerBlock = 0.01 * (10**18)

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

    # Test subscribtion
    subscriptionDuration = 10  # blocks
    value = "0.1 ether"

    depositAndApprove(
        subscriber, rentable, value, paymentToken, paymentTokenId, weth, dummy1155
    )

    rentable.createLease(
        testNFT, tokenId, subscriptionDuration, {"from": subscriber, "value": value}
    )

    leaseId = 1

    chain.mine(5)

    with brownie.reverts("Current lease still pending"):
        rentable.expireLeases([leaseId])

    chain.mine(6)

    rentable.expireLeases([leaseId])

    # Test subscribtion
    subscriptionDuration = 10  # blocks
    value = "0.1 ether"

    depositAndApprove(
        subscriber, rentable, value, paymentToken, paymentTokenId, weth, dummy1155
    )

    rentable.createLease(
        testNFT, tokenId, subscriptionDuration, {"from": subscriber, "value": value}
    )
