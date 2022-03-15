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


def test_deposit_1155(
    rentable, orentable1155, testNFT1155, accounts, dummylib, eternalstorage
):

    # TODO: add test for hooks
    # rentable.setLibrary(testNFT, dummylib)

    # assert rentable.getLibrary(testNFT) == dummylib

    user = accounts[0]

    tokenId = 123
    mintAmount = 3
    transferAmount = 2

    testNFT1155.mint(user, tokenId, mintAmount, {"from": user})

    testNFT1155.setApprovalForAll(rentable, True, {"from": user})

    tx = rentable.deposit1155(testNFT1155, tokenId, transferAmount, {"from": user})

    evt = tx.events["Deposit1155"]

    assert evt["who"] == user
    assert evt["tokenAddress"] == testNFT1155.address
    assert evt["tokenId"] == tokenId
    assert evt["amount"] == transferAmount

    # Test ownership is on orentable
    assert testNFT1155.balanceOf(rentable, tokenId) == 2

    # Test user ownership
    assert orentable1155.balanceOf(user, tokenId) == 2

    # assert eternalstorage.getAddressValue(dummylib.TOKEN_ADDRESS()) == testNFT.address
    # assert eternalstorage.getUIntValue(dummylib.TOKEN_ID()) == tokenId
    # assert eternalstorage.getAddressValue(dummylib.USER()) == user


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
    pricePerBlock = 0.001 * (10**18)

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
    pricePerBlock = 0.001 * (10**18)

    rentable.depositAndList(
        testNFT, tokenId, paymentToken, maxTimeDuration, pricePerBlock, {"from": user}
    )

    lease = rentable.leasesConditions(testNFT, tokenId).dict()

    assert lease["fixedFee"] == currentFixedFee
    assert lease["fee"] == currentFee


def test_deposit1155AndList(
    rentable, orentable1155, testNFT1155, accounts, paymentToken
):
    user = accounts[0]

    tokenId = 123
    mintAmount = 3
    transferAmount = 2

    testNFT1155.mint(user, tokenId, mintAmount, {"from": user})

    testNFT1155.setApprovalForAll(rentable, True, {"from": user})

    maxTimeDuration = 1000  # blocks
    pricePerBlock = 0.001 * (10**18)

    tx = rentable.deposit1155AndList(
        testNFT1155,
        tokenId,
        transferAmount,
        paymentToken,
        maxTimeDuration,
        pricePerBlock,
        {"from": user},
    )

    evt = tx.events["Deposit1155"]

    assert evt["who"] == user
    assert evt["tokenAddress"] == testNFT1155.address
    assert evt["tokenId"] == tokenId
    assert evt["amount"] == transferAmount

    evt = tx.events["UpdateLeaseConditions"]

    assert evt["tokenAddress"] == testNFT1155.address
    assert evt["tokenId"] == tokenId
    assert evt["paymentTokenAddress"] == paymentToken
    assert evt["maxTimeDuration"] == maxTimeDuration
    assert evt["pricePerBlock"] == pricePerBlock

    # Test ownership is on orentable
    assert testNFT1155.balanceOf(rentable, tokenId) == 2

    # Test user ownership
    assert orentable1155.balanceOf(user, tokenId) == 2

    # Test lease created correctly
    currentFixedFee = rentable.getFixedFee()
    currentFee = rentable.getFee()
    lease = rentable.leasesConditions(testNFT1155, tokenId).dict()
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

    lease = rentable.leasesConditions(testNFT1155, tokenId).dict()

    assert lease["fixedFee"] == previousFixedFee
    assert lease["fee"] == previousFee

    tokenId = 124

    testNFT1155.mint(user, tokenId, 1, {"from": user})

    maxTimeDuration = 1000  # blocks
    pricePerBlock = 0.001 * (10**18)

    rentable.deposit1155AndList(
        testNFT1155,
        tokenId,
        1,
        paymentToken,
        maxTimeDuration,
        pricePerBlock,
        {"from": user},
    )

    lease = rentable.leasesConditions(testNFT1155, tokenId).dict()

    assert lease["fixedFee"] == currentFixedFee
    assert lease["fee"] == currentFee


def test_depositAndList_1tx(rentable, orentable, testNFT, accounts, paymentToken):
    user = accounts[0]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    maxTimeDuration = 1000  # blocks
    pricePerBlock = int(0.001 * (10**18))

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
    pricePerBlock = 0.001 * (10**18)

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


def test_withdraw1155(rentable, orentable1155, testNFT1155, accounts):
    user = accounts[0]

    tokenId = 123
    mintAmount = 3
    transferAmount = 2

    testNFT1155.mint(user, tokenId, mintAmount, {"from": user})

    testNFT1155.setApprovalForAll(rentable, True, {"from": user})

    rentable.deposit1155(testNFT1155, tokenId, transferAmount, {"from": user})

    tx = rentable.withdraw1155(testNFT1155, tokenId, transferAmount, {"from": user})

    evt = tx.events["Withdraw1155"]

    assert evt["who"] == user
    assert evt["tokenAddress"] == testNFT1155.address
    assert evt["tokenId"] == tokenId
    assert evt["amount"] == transferAmount

    # Test user ownership
    assert orentable1155.balanceOf(user, tokenId) == 0

    # Test ownership is back on user
    assert testNFT1155.balanceOf(user, tokenId) == mintAmount

    leaseConditions = rentable.leasesConditions(testNFT1155, tokenId)

    assert leaseConditions == (0, 0, "0x0000000000000000000000000000000000000000", 0, 0)


def test_withdraw1155_less(rentable, orentable1155, testNFT1155, accounts):
    user = accounts[0]

    tokenId = 123
    mintAmount = 3
    transferAmount = 2

    testNFT1155.mint(user, tokenId, mintAmount, {"from": user})

    testNFT1155.setApprovalForAll(rentable, True, {"from": user})

    rentable.deposit1155(testNFT1155, tokenId, transferAmount, {"from": user})

    tx = rentable.withdraw1155(testNFT1155, tokenId, transferAmount - 1, {"from": user})

    evt = tx.events["Withdraw1155"]

    assert evt["who"] == user
    assert evt["tokenAddress"] == testNFT1155.address
    assert evt["tokenId"] == tokenId
    assert evt["amount"] == transferAmount - 1

    # Test user ownership
    assert orentable1155.balanceOf(user, tokenId) == 1

    # Test ownership is back on user
    assert testNFT1155.balanceOf(user, tokenId) == mintAmount - 1

    leaseConditions = rentable.leasesConditions(testNFT1155, tokenId)

    assert leaseConditions != (0, 0, "0x0000000000000000000000000000000000000000", 0, 0)


def test_cannot_withdraw1155_zero(rentable, orentable1155, testNFT1155, accounts):
    user = accounts[0]

    tokenId = 123
    mintAmount = 3
    transferAmount = 2

    testNFT1155.mint(user, tokenId, mintAmount, {"from": user})

    testNFT1155.setApprovalForAll(rentable, True, {"from": user})

    rentable.deposit1155(testNFT1155, tokenId, transferAmount, {"from": user})

    with brownie.reverts("Cannot withdraw 0"):
        tx = rentable.withdraw1155(testNFT1155, tokenId, 0, {"from": user})


def test_cannot_withdraw1155_too_much(rentable, orentable1155, testNFT1155, accounts):
    user = accounts[0]

    tokenId = 123
    mintAmount = 3
    transferAmount = 2

    testNFT1155.mint(user, tokenId, mintAmount, {"from": user})

    testNFT1155.setApprovalForAll(rentable, True, {"from": user})

    rentable.deposit1155(testNFT1155, tokenId, transferAmount, {"from": user})

    with brownie.reverts("The token must be yours"):
        tx = rentable.withdraw1155(
            testNFT1155, tokenId, transferAmount + 1, {"from": user}
        )


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
