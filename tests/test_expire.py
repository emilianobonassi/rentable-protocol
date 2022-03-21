from utils import *


def test_rent_after_expire(
    rentable,
    wrentable,
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
    renter = accounts[1]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})

    maxTimeDuration = 1000  # 7 days
    pricePerBlock = 0.01 * (10**18)

    rentable.createOrUpdateRentalConditions(
        testNFT,
        tokenId,
        paymentToken,
        paymentTokenId,
        maxTimeDuration,
        pricePerBlock,
        address0,
        {"from": user},
    )

    # Test rent
    rentalDuration = 10  # blocks
    value = "0.1 ether"

    depositAndApprove(
        renter, rentable, value, paymentToken, paymentTokenId, weth, dummy1155
    )

    rentable.rent(testNFT, tokenId, rentalDuration, {"from": renter, "value": value})

    chain.mine(5)

    rentable.expireRentals([testNFT], [tokenId])

    # Check still exists after nullpotent expireRentals
    assert wrentable.exists(tokenId) == True

    chain.mine(6)

    rentable.expireRentals([testNFT], [tokenId])

    # Check wtoken is burned
    assert wrentable.exists(tokenId) == False

    # Test rent
    rentalDuration = 10  # blocks
    value = "0.1 ether"

    depositAndApprove(
        renter, rentable, value, paymentToken, paymentTokenId, weth, dummy1155
    )

    rentable.rent(testNFT, tokenId, rentalDuration, {"from": renter, "value": value})
