import brownie
from utils import *


def test_create_rental_conditions(
    rentable, testNFT, accounts, paymentToken, paymentTokenId, dummylib, eternalstorage
):

    rentable.setLibrary(testNFT, dummylib)
    assert rentable.getLibrary(testNFT) == dummylib

    user = accounts[0]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})

    maxTimeDuration = 1000  # seconds
    pricePerSecond = 0.001 * (10**18)

    rentable.createOrUpdateRentalConditions(
        testNFT,
        tokenId,
        paymentToken,
        paymentTokenId,
        maxTimeDuration,
        pricePerSecond,
        address0,
        {"from": user},
    )

    # Test rent created correctly
    rent = rentable.rentalConditions(testNFT, tokenId).dict()
    assert rent["maxTimeDuration"] == maxTimeDuration
    assert rent["pricePerSecond"] == pricePerSecond
    assert rent["paymentTokenAddress"] == paymentToken
    assert rent["paymentTokenId"] == paymentTokenId
    assert rent["privateRenter"] == address0

    assert eternalstorage.getAddressValue(dummylib.TOKEN_ADDRESS()) == testNFT.address
    assert eternalstorage.getUIntValue(dummylib.TOKEN_ID()) == tokenId
    assert eternalstorage.getAddressValue(dummylib.USER()) == user
    assert eternalstorage.getUIntValue(dummylib.MAX_TIME_DURATION()) == maxTimeDuration
    assert eternalstorage.getUIntValue(dummylib.PRICE_PER_SECOND()) == pricePerSecond


def test_delete_rental_conditions(
    rentable, testNFT, accounts, paymentToken, paymentTokenId
):
    user = accounts[0]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})

    maxTimeDuration = 1000  # 7 days
    pricePerSecond = 0.001 * (10**18)

    rentable.createOrUpdateRentalConditions(
        testNFT,
        tokenId,
        paymentToken,
        paymentTokenId,
        maxTimeDuration,
        pricePerSecond,
        address0,
        {"from": user},
    )
    rentable.deleteRentalConditions(testNFT, tokenId, {"from": user})

    # Test rent created correctly
    rent = rentable.rentalConditions(testNFT, tokenId).dict()

    assert rent["maxTimeDuration"] == 0


def test_update_rental_conditions(
    rentable, testNFT, accounts, paymentToken, paymentTokenId
):
    user = accounts[0]
    user1 = accounts[1]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})

    maxTimeDuration = 1000  # seconds
    pricePerSecond = 0.001 * (10**18)

    rentable.createOrUpdateRentalConditions(
        testNFT,
        tokenId,
        paymentToken,
        paymentTokenId,
        maxTimeDuration,
        pricePerSecond,
        address0,
        {"from": user},
    )

    # Test rent created correctly
    rent = rentable.rentalConditions(testNFT, tokenId).dict()
    assert rent["maxTimeDuration"] == maxTimeDuration
    assert rent["pricePerSecond"] == pricePerSecond
    assert rent["paymentTokenAddress"] == paymentToken
    assert rent["paymentTokenId"] == paymentTokenId
    assert rent["privateRenter"] == address0

    maxTimeDuration = 800  # seconds
    pricePerSecond = 0.8 * (10**18)

    rentable.createOrUpdateRentalConditions(
        testNFT,
        tokenId,
        paymentToken,
        paymentTokenId,
        maxTimeDuration,
        pricePerSecond,
        user1,
        {"from": user},
    )

    # Test rent update correctly
    rent = rentable.rentalConditions(testNFT, tokenId).dict()
    assert rent["maxTimeDuration"] == maxTimeDuration
    assert rent["pricePerSecond"] == pricePerSecond
    assert rent["paymentTokenAddress"] == paymentToken
    assert rent["paymentTokenId"] == paymentTokenId
    assert rent["privateRenter"] == user1


def test_rent(
    rentableWithFees,
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
    rentableWithFees.setLibrary(testNFT, dummylib)
    assert rentableWithFees.getLibrary(testNFT) == dummylib

    user = accounts[0]
    renter = accounts[1]
    feeCollector = accounts.at(rentableWithFees.feeCollector())

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentableWithFees, tokenId, {"from": user})

    rentableWithFees.deposit(testNFT, tokenId, {"from": user})

    maxTimeDuration = 1000  # 7 days
    pricePerSecond = 0.001 * (10**18)

    rentableWithFees.createOrUpdateRentalConditions(
        testNFT,
        tokenId,
        paymentToken,
        paymentTokenId,
        maxTimeDuration,
        pricePerSecond,
        address0,
        {"from": user},
    )

    # Test rent
    rentalDuration = 70  # seconds
    value = "0.07 ether"

    preBalanceUser = getBalance(user, paymentToken, paymentTokenId, weth, dummy1155)

    preBalanceFeeCollector = getBalance(
        feeCollector, paymentToken, paymentTokenId, weth, dummy1155
    )

    depositAndApprove(
        renter, rentableWithFees, value, paymentToken, paymentTokenId, weth, dummy1155
    )

    preBalanceRenter = getBalance(renter, paymentToken, paymentTokenId, weth, dummy1155)
    tx = rentableWithFees.rent(
        testNFT, tokenId, rentalDuration, {"from": renter, "value": value}
    )

    postBalanceRenter = getBalance(
        renter, paymentToken, paymentTokenId, weth, dummy1155
    )

    rentPayed = preBalanceRenter - postBalanceRenter

    evt = tx.events["Rent"]

    assert evt["from"] == user
    assert evt["to"] == renter
    assert evt["tokenAddress"] == testNFT.address
    assert evt["tokenId"] == tokenId
    assert evt["paymentTokenAddress"] == paymentToken
    assert evt["paymentTokenId"] == paymentTokenId
    assert evt["expiresAt"] == tx.timestamp + rentalDuration

    assert rentableWithFees.expiresAt(testNFT, tokenId) == tx.timestamp + rentalDuration

    totalFeesToPay = (
        (
            (rentPayed - rentableWithFees.fixedFee())
            * rentableWithFees.fee()
            / rentableWithFees.BASE_FEE()
        )
    ) + rentableWithFees.fixedFee()

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

    assert wrentable.ownerOf(tokenId) == renter.address

    assert eternalstorage.getAddressValue(dummylib.TOKEN_ADDRESS()) == testNFT.address
    assert eternalstorage.getUIntValue(dummylib.TOKEN_ID()) == tokenId
    assert eternalstorage.getAddressValue(dummylib.FROM()) == user.address
    assert eternalstorage.getAddressValue(dummylib.TO()) == renter.address
    assert eternalstorage.getUIntValue(dummylib.DURATION()) == rentalDuration

    chain.mine(1, None, rentalDuration + 1)

    assert wrentable.ownerOf(tokenId) == address0


def test_rent_via_depositAndList(
    rentableWithFees,
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
    renter = accounts[1]
    feeCollector = accounts.at(rentableWithFees.feeCollector())

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentableWithFees, tokenId, {"from": user})

    maxTimeDuration = 1000  # seconds
    pricePerSecond = 0.001 * (10**18)

    rentableWithFees.depositAndList(
        testNFT,
        tokenId,
        paymentToken,
        paymentTokenId,
        maxTimeDuration,
        pricePerSecond,
        address0,
        {"from": user},
    )

    # Test rent
    rentalDuration = 80  # seconds
    value = "0.08 ether"

    preBalanceUser = getBalance(user, paymentToken, paymentTokenId, weth, dummy1155)

    preBalanceFeeCollector = getBalance(
        feeCollector, paymentToken, paymentTokenId, weth, dummy1155
    )

    depositAndApprove(
        renter, rentableWithFees, value, paymentToken, paymentTokenId, weth, dummy1155
    )

    preBalanceRenter = getBalance(renter, paymentToken, paymentTokenId, weth, dummy1155)
    tx = rentableWithFees.rent(
        testNFT, tokenId, rentalDuration, {"from": renter, "value": value}
    )

    postBalanceRenter = getBalance(
        renter, paymentToken, paymentTokenId, weth, dummy1155
    )

    rentPayed = preBalanceRenter - postBalanceRenter

    evt = tx.events["Rent"]

    assert evt["from"] == user
    assert evt["to"] == renter
    assert evt["tokenAddress"] == testNFT.address
    assert evt["tokenId"] == tokenId
    assert evt["paymentTokenAddress"] == paymentToken
    assert evt["paymentTokenId"] == paymentTokenId
    assert evt["expiresAt"] == tx.timestamp + rentalDuration

    assert rentableWithFees.expiresAt(testNFT, tokenId) == tx.timestamp + rentalDuration

    totalFeesToPay = (
        (
            (rentPayed - rentableWithFees.fixedFee())
            * rentableWithFees.fee()
            / rentableWithFees.BASE_FEE()
        )
    ) + rentableWithFees.fixedFee()

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

    assert wrentable.ownerOf(tokenId) == renter.address

    chain.mine(1, None, rentalDuration + 1)

    assert wrentable.ownerOf(tokenId) == address0

    tx = rentableWithFees.expireRental(testNFT, tokenId)

    evt = tx.events["RentEnds"]

    assert evt["tokenAddress"] == testNFT.address
    assert evt["tokenId"] == tokenId


def test_rent_via_depositAndList_private(
    rentableWithFees,
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
    renter = accounts[1]
    wrongRenter = accounts[2]

    feeCollector = accounts.at(rentableWithFees.feeCollector())

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentableWithFees, tokenId, {"from": user})

    maxTimeDuration = 1000  # seconds
    pricePerSecond = 0.001 * (10**18)

    rentableWithFees.depositAndList(
        testNFT,
        tokenId,
        paymentToken,
        paymentTokenId,
        maxTimeDuration,
        pricePerSecond,
        renter,
        {"from": user},
    )

    # Test rent
    rentalDuration = 80  # seconds
    value = "0.08 ether"

    preBalanceUser = getBalance(user, paymentToken, paymentTokenId, weth, dummy1155)

    preBalanceFeeCollector = getBalance(
        feeCollector, paymentToken, paymentTokenId, weth, dummy1155
    )

    depositAndApprove(
        renter, rentableWithFees, value, paymentToken, paymentTokenId, weth, dummy1155
    )
    depositAndApprove(
        wrongRenter,
        rentableWithFees,
        value,
        paymentToken,
        paymentTokenId,
        weth,
        dummy1155,
    )

    preBalanceRenter = getBalance(renter, paymentToken, paymentTokenId, weth, dummy1155)

    with brownie.reverts("Rental reserved for another user"):
        tx = rentableWithFees.rent(
            testNFT,
            tokenId,
            rentalDuration,
            {"from": wrongRenter, "value": value},
        )
    tx = rentableWithFees.rent(
        testNFT, tokenId, rentalDuration, {"from": renter, "value": value}
    )

    postBalanceRenter = getBalance(
        renter, paymentToken, paymentTokenId, weth, dummy1155
    )

    rentPayed = preBalanceRenter - postBalanceRenter

    evt = tx.events["Rent"]

    assert evt["from"] == user
    assert evt["to"] == renter
    assert evt["tokenAddress"] == testNFT.address
    assert evt["tokenId"] == tokenId
    assert evt["paymentTokenAddress"] == paymentToken
    assert evt["paymentTokenId"] == paymentTokenId
    assert evt["expiresAt"] == tx.timestamp + rentalDuration

    assert rentableWithFees.expiresAt(testNFT, tokenId) == tx.timestamp + rentalDuration

    totalFeesToPay = (
        (
            (rentPayed - rentableWithFees.fixedFee())
            * rentableWithFees.fee()
            / rentableWithFees.BASE_FEE()
        )
    ) + rentableWithFees.fixedFee()

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

    assert wrentable.ownerOf(tokenId) == renter.address

    chain.mine(1, None, rentalDuration + 1)

    assert wrentable.ownerOf(tokenId) == address0

    tx = rentableWithFees.expireRental(testNFT, tokenId)

    evt = tx.events["RentEnds"]

    assert evt["tokenAddress"] == testNFT.address
    assert evt["tokenId"] == tokenId


def test_do_not_withdraw_on_rent(
    rentable, testNFT, paymentToken, paymentTokenId, weth, dummy1155, accounts, chain
):
    user = accounts[0]
    renter = accounts[1]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})

    maxTimeDuration = 1000  # seconds
    pricePerSecond = 0.001 * (10**18)

    rentable.createOrUpdateRentalConditions(
        testNFT,
        tokenId,
        paymentToken,
        paymentTokenId,
        maxTimeDuration,
        pricePerSecond,
        address0,
        {"from": user},
    )

    # Test rent
    rentalDuration = 40
    value = "0.04 ether"

    depositAndApprove(
        renter, rentable, value, paymentToken, paymentTokenId, weth, dummy1155
    )
    tx = rentable.rent(
        testNFT, tokenId, rentalDuration, {"from": renter, "value": value}
    )

    evt = tx.events["Rent"]

    assert evt["from"] == user
    assert evt["to"] == renter
    assert evt["tokenAddress"] == testNFT.address
    assert evt["tokenId"] == tokenId
    assert evt["paymentTokenAddress"] == paymentToken
    assert evt["paymentTokenId"] == paymentTokenId
    assert evt["expiresAt"] == tx.timestamp + rentalDuration

    with brownie.reverts("Current rent still pending"):
        rentable.withdraw(testNFT, tokenId, {"from": user})

    chain.mine(1, None, 40 + 1)

    rentable.withdraw(testNFT, tokenId, {"from": user})


def test_transfer_rent(
    rentable,
    testNFT,
    paymentToken,
    paymentTokenId,
    weth,
    dummy1155,
    accounts,
    wrentable,
    dummylib,
):
    rentable.setLibrary(testNFT, dummylib)
    assert rentable.getLibrary(testNFT) == dummylib

    user = accounts[0]
    renter = accounts[1]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})

    maxTimeDuration = 1000  # seconds
    pricePerSecond = 0.001 * (10**18)

    rentable.createOrUpdateRentalConditions(
        testNFT,
        tokenId,
        paymentToken,
        paymentTokenId,
        maxTimeDuration,
        pricePerSecond,
        address0,
        {"from": user},
    )

    # Test rent
    rentalDuration = 40
    value = "0.04 ether"

    depositAndApprove(
        renter, rentable, value, paymentToken, paymentTokenId, weth, dummy1155
    )
    tx = rentable.rent(
        testNFT, tokenId, rentalDuration, {"from": renter, "value": value}
    )

    evt = tx.events["Rent"]

    assert evt["from"] == user
    assert evt["to"] == renter
    assert evt["tokenAddress"] == testNFT.address
    assert evt["tokenId"] == tokenId
    assert evt["paymentTokenAddress"] == paymentToken
    assert evt["paymentTokenId"] == paymentTokenId
    assert evt["expiresAt"] == tx.timestamp + rentalDuration

    user2 = accounts[2]

    wrentable.transferFrom(renter, user2, tokenId, {"from": renter})

    assert testNFT.ownerOf(tokenId) == rentable.address
    assert wrentable.ownerOf(tokenId) == user2


def test_transfer_ownership_during_rent(
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
    renter = accounts[1]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})

    maxTimeDuration = 1000  # seconds
    pricePerSecond = 0.001 * (10**18)

    rentable.createOrUpdateRentalConditions(
        testNFT,
        tokenId,
        paymentToken,
        paymentTokenId,
        maxTimeDuration,
        pricePerSecond,
        address0,
        {"from": user},
    )

    # Test rent
    rentalDuration = 40
    value = "0.04 ether"

    depositAndApprove(
        renter, rentable, value, paymentToken, paymentTokenId, weth, dummy1155
    )
    tx = rentable.rent(
        testNFT, tokenId, rentalDuration, {"from": renter, "value": value}
    )

    evt = tx.events["Rent"]

    assert evt["from"] == user
    assert evt["to"] == renter
    assert evt["tokenAddress"] == testNFT.address
    assert evt["tokenId"] == tokenId
    assert evt["paymentTokenAddress"] == paymentToken
    assert evt["paymentTokenId"] == paymentTokenId
    assert evt["expiresAt"] == tx.timestamp + rentalDuration

    user2 = accounts[2]

    orentable.transferFrom(user, user2, tokenId, {"from": user})

    assert testNFT.ownerOf(tokenId) == rentable.address
    assert orentable.ownerOf(tokenId) == user2

    assert eternalstorage.getAddressValue(dummylib.TOKEN_ADDRESS()) == testNFT.address
    assert eternalstorage.getUIntValue(dummylib.TOKEN_ID()) == tokenId
    assert eternalstorage.getAddressValue(dummylib.FROM()) == user
    assert eternalstorage.getAddressValue(dummylib.TO()) == user2
