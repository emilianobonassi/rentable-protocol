import pytest
import brownie
import eth_abi
from brownie import Wei
from utils import address0


def deposit1tx(
    rentable,
    nft,
    depositor,
    tokenId,
    maxTimeDuration,
    pricePerSecond,
    paymentToken,
    paymentTokenId,
):
    data = eth_abi.encode_abi(
        [
            "uint256",  # maxTimeDuration
            "uint256",  # pricePerSecond
            "uint256",  # paymentTokenId
            "address",  # paymentTokenAddress
            "address",  # privateRental
        ],
        (maxTimeDuration, pricePerSecond, paymentTokenId, paymentToken, address0),
    ).hex()

    return nft.safeTransferFrom(depositor, rentable, tokenId, data, {"from": depositor})


def test_flow(rentable, interface, testLand, accounts, chain, deployer, paymentTokenId):
    oLand = interface.IERC721(rentable.getORentable(testLand))
    wLand = interface.IERC721(rentable.getWRentable(testLand))

    # Land owned by originalOwner and with originalOperator as operator
    # List for maxSeconds and pricePerSecond payed in currencyToken
    # Onwer transfer to newOwner
    # Renter rent for half of the time
    # Transfer to newRenter
    # newOwner redeem after expire

    originalOwner = accounts[0]
    tokenId = 123
    originalOperator = accounts[1]
    renter = accounts[3]
    newRenter = accounts[4]
    newOwner = accounts[5]

    # Init

    testLand.mint(originalOwner, tokenId)
    assert testLand.ownerOf(tokenId) == originalOwner

    testLand.setUpdateOperator(tokenId, originalOperator)
    assert testLand.updateOperator(tokenId) == originalOperator

    # List
    maxSeconds = 10
    pricePerSecond = int(0.1 * (10**18))
    currencyToken = address0

    deposit1tx(
        rentable,
        testLand,
        originalOwner,
        tokenId,
        maxSeconds,
        pricePerSecond,
        currencyToken,
        paymentTokenId,
    )

    assert testLand.updateOperator(tokenId) == originalOwner

    # Transfer ownership not rented should change operator
    oLand.safeTransferFrom(originalOwner, newOwner, tokenId, {"from": originalOwner})

    assert testLand.updateOperator(tokenId) == newOwner

    # Rent
    tx = rentable.rent(
        testLand, tokenId, maxSeconds / 2, {"from": renter, "value": "1 ether"}
    )

    assert testLand.updateOperator(tokenId) == renter

    # Transfer newRenter

    wLand.safeTransferFrom(renter, newRenter, tokenId, {"from": renter})

    assert testLand.updateOperator(tokenId) == newRenter

    # Transfer ownership rented - must not change operator

    oLand.safeTransferFrom(newOwner, originalOwner, tokenId, {"from": newOwner})

    assert testLand.updateOperator(tokenId) == newRenter  # must not change

    # Timemachine

    chain.mine(1, None, maxSeconds + 1)

    # Expire
    rentable.expireRental(testLand, tokenId, {"from": deployer})

    # Original Owner will be the updateOperator again

    assert testLand.updateOperator(tokenId) == originalOwner  # must not change

    rentable.withdraw(testLand, tokenId, {"from": originalOwner})

    assert testLand.updateOperator(tokenId) == address0  # must not change
