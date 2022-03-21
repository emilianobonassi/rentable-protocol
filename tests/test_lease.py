from multiprocessing import dummy
import brownie
import eth_abi
from utils import *


def test_create_lease(
    rentable, testNFT, accounts, paymentToken, paymentTokenId, dummylib, eternalstorage
):

    rentable.setLibrary(testNFT, dummylib)
    assert rentable.getLibrary(testNFT) == dummylib

    user = accounts[0]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})

    maxTimeDuration = 1000  # blocks
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

    # Test lease created correctly
    lease = rentable.leasesConditions(testNFT, tokenId).dict()
    assert lease["maxTimeDuration"] == maxTimeDuration
    assert lease["pricePerBlock"] == pricePerBlock
    assert lease["paymentTokenAddress"] == paymentToken
    assert lease["paymentTokenId"] == paymentTokenId
    assert lease["privateRenter"] == address0

    assert eternalstorage.getAddressValue(dummylib.TOKEN_ADDRESS()) == testNFT.address
    assert eternalstorage.getUIntValue(dummylib.TOKEN_ID()) == tokenId
    assert eternalstorage.getAddressValue(dummylib.USER()) == user
    assert eternalstorage.getUIntValue(dummylib.MAX_TIME_DURATION()) == maxTimeDuration
    assert eternalstorage.getUIntValue(dummylib.PRICE_PER_BLOCK()) == pricePerBlock


def test_delete_lease(rentable, testNFT, accounts, paymentToken, paymentTokenId):
    user = accounts[0]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})

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
    rentable.deleteLeaseConditions(testNFT, tokenId, {"from": user})

    # Test lease created correctly
    lease = rentable.leasesConditions(testNFT, tokenId).dict()

    assert lease["maxTimeDuration"] == 0


def test_update_lease(rentable, testNFT, accounts, paymentToken, paymentTokenId):
    user = accounts[0]
    user1 = accounts[1]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})

    maxTimeDuration = 1000  # blocks
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

    # Test lease created correctly
    lease = rentable.leasesConditions(testNFT, tokenId).dict()
    assert lease["maxTimeDuration"] == maxTimeDuration
    assert lease["pricePerBlock"] == pricePerBlock
    assert lease["paymentTokenAddress"] == paymentToken
    assert lease["paymentTokenId"] == paymentTokenId
    assert lease["privateRenter"] == address0

    maxTimeDuration = 800  # blocks
    pricePerBlock = 0.8 * (10**18)

    rentable.createOrUpdateLeaseConditions(
        testNFT,
        tokenId,
        paymentToken,
        paymentTokenId,
        maxTimeDuration,
        pricePerBlock,
        user1,
        {"from": user},
    )

    # Test lease update correctly
    lease = rentable.leasesConditions(testNFT, tokenId).dict()
    assert lease["maxTimeDuration"] == maxTimeDuration
    assert lease["pricePerBlock"] == pricePerBlock
    assert lease["paymentTokenAddress"] == paymentToken
    assert lease["paymentTokenId"] == paymentTokenId
    assert lease["privateRenter"] == user1


def test_subscribe_lease(
    rentable,
    testNFT,
    paymentToken,
    paymentTokenId,
    accounts,
    wrentable,
    chain,
    weth,
    dummy1155,
    feeCollector,
    dummylib,
    eternalstorage,
):
    rentable.setLibrary(testNFT, dummylib)
    assert rentable.getLibrary(testNFT) == dummylib

    user = accounts[0]
    subscriber = accounts[1]
    feeCollector = accounts.at(rentable.feeCollector())

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})

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

    # Test subscribtion
    subscriptionDuration = 70  # blocks
    value = "0.07 ether"

    preBalanceUser = getBalance(user, paymentToken, paymentTokenId, weth, dummy1155)

    preBalanceFeeCollector = getBalance(
        feeCollector, paymentToken, paymentTokenId, weth, dummy1155
    )

    depositAndApprove(
        subscriber, rentable, value, paymentToken, paymentTokenId, weth, dummy1155
    )

    preBalanceSubscriber = getBalance(
        subscriber, paymentToken, paymentTokenId, weth, dummy1155
    )
    tx = rentable.createLease(
        testNFT, tokenId, subscriptionDuration, {"from": subscriber, "value": value}
    )

    postBalanceSubscriber = getBalance(
        subscriber, paymentToken, paymentTokenId, weth, dummy1155
    )

    rentPayed = preBalanceSubscriber - postBalanceSubscriber

    evt = tx.events["Rent"]

    assert evt["from"] == user
    assert evt["to"] == subscriber
    assert evt["tokenAddress"] == testNFT.address
    assert evt["tokenId"] == tokenId

    assert (
        rentable.expiresAt(testNFT, tokenId) == tx.block_number + subscriptionDuration
    )

    totalFeesToPay = (
        ((rentPayed - rentable.fixedFee()) * rentable.fee() / rentable.BASE_FEE())
    ) + rentable.fixedFee()

    assert (
        getBalance(feeCollector, paymentToken, paymentTokenId, weth, dummy1155)
        - preBalanceFeeCollector
        == totalFeesToPay
    )

    renteePayout = rentPayed - totalFeesToPay

    assert (
        getBalance(user, paymentToken, paymentTokenId, weth, dummy1155) - preBalanceUser
        == renteePayout
    )

    assert wrentable.ownerOf(tokenId) == subscriber.address

    assert eternalstorage.getAddressValue(dummylib.TOKEN_ADDRESS()) == testNFT.address
    assert eternalstorage.getUIntValue(dummylib.TOKEN_ID()) == tokenId
    assert eternalstorage.getAddressValue(dummylib.FROM()) == user.address
    assert eternalstorage.getAddressValue(dummylib.TO()) == subscriber.address
    assert eternalstorage.getUIntValue(dummylib.DURATION()) == subscriptionDuration

    chain.mine(subscriptionDuration + 1)

    assert wrentable.ownerOf(tokenId) == address0


def test_subscribe_lease_via_depositAndList(
    rentable,
    testNFT,
    paymentToken,
    paymentTokenId,
    accounts,
    wrentable,
    chain,
    weth,
    dummy1155,
    feeCollector,
):
    user = accounts[0]
    subscriber = accounts[1]
    feeCollector = accounts.at(rentable.feeCollector())

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    maxTimeDuration = 1000  # blocks
    pricePerBlock = 0.001 * (10**18)

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

    # Test subscribtion
    subscriptionDuration = 80  # blocks
    value = "0.08 ether"

    preBalanceUser = getBalance(user, paymentToken, paymentTokenId, weth, dummy1155)

    preBalanceFeeCollector = getBalance(
        feeCollector, paymentToken, paymentTokenId, weth, dummy1155
    )

    depositAndApprove(
        subscriber, rentable, value, paymentToken, paymentTokenId, weth, dummy1155
    )

    preBalanceSubscriber = getBalance(
        subscriber, paymentToken, paymentTokenId, weth, dummy1155
    )
    tx = rentable.createLease(
        testNFT, tokenId, subscriptionDuration, {"from": subscriber, "value": value}
    )

    postBalanceSubscriber = getBalance(
        subscriber, paymentToken, paymentTokenId, weth, dummy1155
    )

    rentPayed = preBalanceSubscriber - postBalanceSubscriber

    evt = tx.events["Rent"]

    assert evt["from"] == user
    assert evt["to"] == subscriber
    assert evt["tokenAddress"] == testNFT.address
    assert evt["tokenId"] == tokenId

    assert (
        rentable.expiresAt(testNFT, tokenId) == tx.block_number + subscriptionDuration
    )

    totalFeesToPay = (
        ((rentPayed - rentable.fixedFee()) * rentable.fee() / rentable.BASE_FEE())
    ) + rentable.fixedFee()

    assert (
        getBalance(feeCollector, paymentToken, paymentTokenId, weth, dummy1155)
        - preBalanceFeeCollector
        == totalFeesToPay
    )

    renteePayout = rentPayed - totalFeesToPay

    assert (
        getBalance(user, paymentToken, paymentTokenId, weth, dummy1155) - preBalanceUser
        == renteePayout
    )

    assert wrentable.ownerOf(tokenId) == subscriber.address

    chain.mine(subscriptionDuration + 1)

    assert wrentable.ownerOf(tokenId) == address0

    tx = rentable.expireLease(testNFT, tokenId)

    evt = tx.events["RentEnds"]

    assert evt["tokenAddress"] == testNFT.address
    assert evt["tokenId"] == tokenId


def test_subscribe_lease_via_depositAndList_private(
    rentable,
    testNFT,
    paymentToken,
    paymentTokenId,
    accounts,
    wrentable,
    chain,
    weth,
    dummy1155,
    feeCollector,
):
    user = accounts[0]
    subscriber = accounts[1]
    wrongSubscriber = accounts[2]

    feeCollector = accounts.at(rentable.feeCollector())

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    maxTimeDuration = 1000  # blocks
    pricePerBlock = 0.001 * (10**18)

    rentable.depositAndList(
        testNFT,
        tokenId,
        paymentToken,
        paymentTokenId,
        maxTimeDuration,
        pricePerBlock,
        subscriber,
        {"from": user},
    )

    # Test subscribtion
    subscriptionDuration = 80  # blocks
    value = "0.08 ether"

    preBalanceUser = getBalance(user, paymentToken, paymentTokenId, weth, dummy1155)

    preBalanceFeeCollector = getBalance(
        feeCollector, paymentToken, paymentTokenId, weth, dummy1155
    )

    depositAndApprove(
        subscriber, rentable, value, paymentToken, paymentTokenId, weth, dummy1155
    )
    depositAndApprove(
        wrongSubscriber, rentable, value, paymentToken, paymentTokenId, weth, dummy1155
    )

    preBalanceSubscriber = getBalance(
        subscriber, paymentToken, paymentTokenId, weth, dummy1155
    )

    with brownie.reverts("Rental reserved for another user"):
        tx = rentable.createLease(
            testNFT,
            tokenId,
            subscriptionDuration,
            {"from": wrongSubscriber, "value": value},
        )
    tx = rentable.createLease(
        testNFT, tokenId, subscriptionDuration, {"from": subscriber, "value": value}
    )

    postBalanceSubscriber = getBalance(
        subscriber, paymentToken, paymentTokenId, weth, dummy1155
    )

    rentPayed = preBalanceSubscriber - postBalanceSubscriber

    evt = tx.events["Rent"]

    assert evt["from"] == user
    assert evt["to"] == subscriber
    assert evt["tokenAddress"] == testNFT.address
    assert evt["tokenId"] == tokenId

    assert (
        rentable.expiresAt(testNFT, tokenId) == tx.block_number + subscriptionDuration
    )
    totalFeesToPay = (
        ((rentPayed - rentable.fixedFee()) * rentable.fee() / rentable.BASE_FEE())
    ) + rentable.fixedFee()

    assert (
        getBalance(feeCollector, paymentToken, paymentTokenId, weth, dummy1155)
        - preBalanceFeeCollector
        == totalFeesToPay
    )

    renteePayout = rentPayed - totalFeesToPay

    assert (
        getBalance(user, paymentToken, paymentTokenId, weth, dummy1155) - preBalanceUser
        == renteePayout
    )

    assert wrentable.ownerOf(tokenId) == subscriber.address

    chain.mine(subscriptionDuration + 1)

    assert wrentable.ownerOf(tokenId) == address0

    tx = rentable.expireLease(testNFT, tokenId)

    evt = tx.events["RentEnds"]

    assert evt["tokenAddress"] == testNFT.address
    assert evt["tokenId"] == tokenId


def test_do_not_withdraw_on_lease(
    rentable, testNFT, paymentToken, paymentTokenId, weth, dummy1155, accounts, chain
):
    user = accounts[0]
    subscriber = accounts[1]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})

    maxTimeDuration = 1000  # blocks
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

    # Test subscribtion
    subscriptionDuration = 40
    value = "0.04 ether"

    depositAndApprove(
        subscriber, rentable, value, paymentToken, paymentTokenId, weth, dummy1155
    )
    tx = rentable.createLease(
        testNFT, tokenId, subscriptionDuration, {"from": subscriber, "value": value}
    )

    evt = tx.events["Rent"]

    assert evt["from"] == user
    assert evt["to"] == subscriber
    assert evt["tokenAddress"] == testNFT.address
    assert evt["tokenId"] == tokenId

    with brownie.reverts("Current lease still pending"):
        rentable.withdraw(testNFT, tokenId, {"from": user})

    chain.mine(40 + 1)

    rentable.withdraw(testNFT, tokenId, {"from": user})


def test_transfer_lease(
    rentable,
    testNFT,
    paymentToken,
    paymentTokenId,
    weth,
    dummy1155,
    accounts,
    wrentable,
    dummylib,
    eternalstorage,
):
    rentable.setLibrary(testNFT, dummylib)
    assert rentable.getLibrary(testNFT) == dummylib

    user = accounts[0]
    subscriber = accounts[1]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})

    maxTimeDuration = 1000  # blocks
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

    # Test subscribtion
    subscriptionDuration = 40
    value = "0.04 ether"

    depositAndApprove(
        subscriber, rentable, value, paymentToken, paymentTokenId, weth, dummy1155
    )
    tx = rentable.createLease(
        testNFT, tokenId, subscriptionDuration, {"from": subscriber, "value": value}
    )

    evt = tx.events["Rent"]

    assert evt["from"] == user
    assert evt["to"] == subscriber
    assert evt["tokenAddress"] == testNFT.address
    assert evt["tokenId"] == tokenId

    user2 = accounts[2]

    wrentable.transferFrom(subscriber, user2, tokenId, {"from": subscriber})

    assert testNFT.ownerOf(tokenId) == rentable.address
    assert wrentable.ownerOf(tokenId) == user2


def test_transfer_ownership_during_lease(
    rentable,
    testNFT,
    paymentToken,
    paymentTokenId,
    weth,
    dummy1155,
    accounts,
    orentable,
    dummylib,
    eternalstorage,
):
    rentable.setLibrary(testNFT, dummylib)
    assert rentable.getLibrary(testNFT) == dummylib

    user = accounts[0]
    subscriber = accounts[1]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})

    maxTimeDuration = 1000  # blocks
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

    # Test subscribtion
    subscriptionDuration = 40
    value = "0.04 ether"

    depositAndApprove(
        subscriber, rentable, value, paymentToken, paymentTokenId, weth, dummy1155
    )
    tx = rentable.createLease(
        testNFT, tokenId, subscriptionDuration, {"from": subscriber, "value": value}
    )

    evt = tx.events["Rent"]

    assert evt["from"] == user
    assert evt["to"] == subscriber
    assert evt["tokenAddress"] == testNFT.address
    assert evt["tokenId"] == tokenId

    user2 = accounts[2]

    orentable.transferFrom(user, user2, tokenId, {"from": user})

    assert testNFT.ownerOf(tokenId) == rentable.address
    assert orentable.ownerOf(tokenId) == user2

    assert eternalstorage.getAddressValue(dummylib.TOKEN_ADDRESS()) == testNFT.address
    assert eternalstorage.getUIntValue(dummylib.TOKEN_ID()) == tokenId
    assert eternalstorage.getAddressValue(dummylib.FROM()) == user
    assert eternalstorage.getAddressValue(dummylib.TO()) == user2
