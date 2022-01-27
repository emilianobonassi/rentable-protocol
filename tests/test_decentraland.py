import pytest
import brownie
import eth_abi
from brownie import Wei


def deposit1tx(
    rentable, nft, depositor, tokenId, maxTimeDuration, pricePerBlock, paymentToken
):
    data = eth_abi.encode_abi(
        [
            "address",  # paymentTokenAddress
            "uint256",  # maxTimeDuration
            "uint256",  # pricePerBlock
        ],
        (paymentToken, maxTimeDuration, pricePerBlock),
    ).hex()

    return nft.safeTransferFrom(depositor, rentable, tokenId, data, {"from": depositor})


def test_flow(rentable, interface, testLand, accounts, chain, deployer):
    oLand = interface.IERC721(rentable.getORentable(testLand))
    wLand = interface.IERC721(rentable.getWRentable(testLand))

    # Land owned by originalOwner and with originalOperator as operator
    # List for maxLeaseBlocks and pricePerBlock payed in currencyToken
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
    maxLeaseBlocks = 10
    pricePerBlock = int(0.1 * (10 ** 18))
    currencyToken = "0x0000000000000000000000000000000000000000"

    deposit1tx(
        rentable,
        testLand,
        originalOwner,
        tokenId,
        maxLeaseBlocks,
        pricePerBlock,
        currencyToken,
    )

    assert testLand.updateOperator(tokenId) == originalOwner

    # Transfer ownership not rented should change operator
    oLand.safeTransferFrom(originalOwner, newOwner, tokenId, {"from": originalOwner})

    assert testLand.updateOperator(tokenId) == newOwner

    # Lease
    tx = rentable.createLease(
        testLand, tokenId, maxLeaseBlocks / 2, {"from": renter, "value": "1 ether"}
    )
    leaseId = tx.events["Rent"]["yTokenId"]

    assert testLand.updateOperator(tokenId) == renter

    # Transfer newRenter

    wLand.safeTransferFrom(renter, newRenter, tokenId, {"from": renter})

    assert testLand.updateOperator(tokenId) == newRenter

    # Transfer ownership rented - must not change operator

    oLand.safeTransferFrom(newOwner, originalOwner, tokenId, {"from": newOwner})

    assert testLand.updateOperator(tokenId) == newRenter  # must not change

    # Timemachine

    chain.mine(maxLeaseBlocks + 1)

    # Expire
    rentable.expireLease(leaseId, {"from": deployer})

    # Original Owner will be the updateOperator again

    assert testLand.updateOperator(tokenId) == originalOwner  # must not change

    rentable.withdraw(testLand, tokenId, {"from": originalOwner})

    assert (
        testLand.updateOperator(tokenId) == "0x0000000000000000000000000000000000000000"
    )  # must not change
