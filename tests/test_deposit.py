import pytest
import brownie
import eth_abi
from brownie import Wei


def test_deposit(rentable, orentable, testNFT, accounts, dummylib, eternalstorage):

    rentable.setLibrary(testNFT, dummylib)

    assert rentable.getLibrary(testNFT) == dummylib

    user = accounts[0]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    tx = rentable.deposit(testNFT, tokenId, {"from": user})

    evt = tx.events["Deposit"]

    assert evt["who"] == user
    assert evt["tokenAddress"] == testNFT.address
    assert evt["tokenId"] == tokenId

    # Test ownership is on orentable
    assert testNFT.ownerOf(tokenId) == rentable.address

    # Test user ownership
    assert orentable.ownerOf(tokenId) == user

    assert eternalstorage.getAddressValue(dummylib.TOKEN_ADDRESS()) == testNFT.address
    assert eternalstorage.getUIntValue(dummylib.TOKEN_ID()) == tokenId
    assert eternalstorage.getAddressValue(dummylib.USER()) == user


def test_deposit_1tx(rentable, orentable, testNFT, accounts):
    user = accounts[0]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    tx = testNFT.safeTransferFrom(user, rentable, tokenId, {"from": user})

    evt = tx.events["Deposit"]

    assert evt["who"] == user
    assert evt["tokenAddress"] == testNFT.address
    assert evt["tokenId"] == tokenId

    # Test ownership is on orentable
    assert testNFT.ownerOf(tokenId) == rentable.address

    # Test user ownership
    assert orentable.ownerOf(tokenId) == user


def test_depositAndList(rentable, orentable, testNFT, accounts, paymentToken):
    user = accounts[0]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    maxTimeDuration = 1000  # blocks
    pricePerBlock = 0.001 * (10 ** 18)

    tx = rentable.depositAndList(
        testNFT, tokenId, paymentToken, maxTimeDuration, pricePerBlock, {"from": user}
    )

    evt = tx.events["Deposit"]

    assert evt["who"] == user
    assert evt["tokenAddress"] == testNFT.address
    assert evt["tokenId"] == tokenId

    evt = tx.events["UpdateLeaseConditions"]

    assert evt["tokenAddress"] == testNFT.address
    assert evt["tokenId"] == tokenId
    assert evt["paymentTokenAddress"] == paymentToken
    assert evt["maxTimeDuration"] == maxTimeDuration
    assert evt["pricePerBlock"] == pricePerBlock

    # Test ownership is on orentable
    assert testNFT.ownerOf(tokenId) == rentable.address

    # Test user ownership
    assert orentable.ownerOf(tokenId) == user

    # Test lease created correctly
    currentFixedFee = rentable.getFixedFee()
    currentFee = rentable.getFee()
    lease = rentable.leasesConditions(testNFT, tokenId).dict()
    assert lease["maxTimeDuration"] == maxTimeDuration
    assert lease["pricePerBlock"] == pricePerBlock
    assert lease["paymentTokenAddress"] == paymentToken
    assert lease["fixedFee"] == currentFixedFee
    assert lease["fee"] == currentFee

    previousFixedFee = currentFixedFee
    previousFee = currentFee

    # Change fees, previous listings not affected only new ones
    rentable.setFixedFee("0.5 ether")
    rentable.setFee(800)

    currentFixedFee = rentable.getFixedFee()
    currentFee = rentable.getFee()

    lease = rentable.leasesConditions(testNFT, tokenId).dict()

    assert lease["fixedFee"] == previousFixedFee
    assert lease["fee"] == previousFee

    tokenId = 124

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    maxTimeDuration = 1000  # blocks
    pricePerBlock = 0.001 * (10 ** 18)

    rentable.depositAndList(
        testNFT, tokenId, paymentToken, maxTimeDuration, pricePerBlock, {"from": user}
    )

    lease = rentable.leasesConditions(testNFT, tokenId).dict()

    assert lease["fixedFee"] == currentFixedFee
    assert lease["fee"] == currentFee


def test_depositAndList_1tx(rentable, orentable, testNFT, accounts, paymentToken):
    user = accounts[0]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    maxTimeDuration = 1000  # blocks
    pricePerBlock = int(0.001 * (10 ** 18))

    data = eth_abi.encode_abi(
        [
            "address",  # paymentTokenAddress
            "uint256",  # maxTimeDuration
            "uint256",  # pricePerBlock
        ],
        (paymentToken, maxTimeDuration, pricePerBlock),
    ).hex()

    tx = testNFT.safeTransferFrom(user, rentable, tokenId, data, {"from": user})

    evt = tx.events["Deposit"]

    assert evt["who"] == user
    assert evt["tokenAddress"] == testNFT.address
    assert evt["tokenId"] == tokenId

    evt = tx.events["UpdateLeaseConditions"]

    assert evt["tokenAddress"] == testNFT.address
    assert evt["tokenId"] == tokenId
    assert evt["paymentTokenAddress"] == paymentToken
    assert evt["maxTimeDuration"] == maxTimeDuration
    assert evt["pricePerBlock"] == pricePerBlock

    # Test ownership is on orentable
    assert testNFT.ownerOf(tokenId) == rentable.address

    # Test user ownership
    assert orentable.ownerOf(tokenId) == user

    # Test lease created correctly
    currentFixedFee = rentable.getFixedFee()
    currentFee = rentable.getFee()
    lease = rentable.leasesConditions(testNFT, tokenId).dict()
    assert lease["maxTimeDuration"] == maxTimeDuration
    assert lease["pricePerBlock"] == pricePerBlock
    assert lease["paymentTokenAddress"] == paymentToken
    assert lease["fixedFee"] == currentFixedFee
    assert lease["fee"] == currentFee

    previousFixedFee = currentFixedFee
    previousFee = currentFee

    # Change fees, previous listings not affected only new ones
    rentable.setFixedFee("0.5 ether")
    rentable.setFee(800)

    currentFixedFee = rentable.getFixedFee()
    currentFee = rentable.getFee()

    lease = rentable.leasesConditions(testNFT, tokenId).dict()

    assert lease["fixedFee"] == previousFixedFee
    assert lease["fee"] == previousFee

    tokenId = 124

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    maxTimeDuration = 1000  # blocks
    pricePerBlock = 0.001 * (10 ** 18)

    rentable.depositAndList(
        testNFT, tokenId, paymentToken, maxTimeDuration, pricePerBlock, {"from": user}
    )

    lease = rentable.leasesConditions(testNFT, tokenId).dict()

    assert lease["fixedFee"] == currentFixedFee
    assert lease["fee"] == currentFee


def test_withdraw(rentable, orentable, testNFT, accounts):
    user = accounts[0]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})

    tx = rentable.withdraw(testNFT, tokenId, {"from": user})

    evt = tx.events["Withdraw"]

    assert evt["who"] == user
    assert evt["tokenAddress"] == testNFT.address
    assert evt["tokenId"] == tokenId

    # Test user ownership
    with brownie.reverts("ERC721: owner query for nonexistent token"):
        orentable.ownerOf(tokenId)

    # Test ownership is back on user
    assert testNFT.ownerOf(tokenId) == user.address


def test_transfer(rentable, orentable, testNFT, accounts):
    userA = accounts[0]
    userB = accounts[1]

    tokenId = 123

    testNFT.mint(userA, tokenId, {"from": userA})

    testNFT.approve(rentable, tokenId, {"from": userA})

    rentable.deposit(testNFT, tokenId, {"from": userA})

    orentable.transferFrom(userA, userB, tokenId, {"from": userA})

    # Test ownership is on orentable
    assert testNFT.ownerOf(tokenId) == rentable.address

    # Test deposit map
    assert orentable.ownerOf(tokenId) == userB
