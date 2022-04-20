import eth_abi
import random

from brownie import (
    accounts,
    TestNFT,
)


def chunks(lst, n):
    """Yield successive n-sized chunks from lst."""
    for i in range(0, len(lst), n):
        yield lst[i : i + n]


def listOnMarket(
    user,
    token,
    rentable,
    tokenId,
    maxTimeDuration,
    pricePerSecond,
    paymentTokenId,
    paymentTokenAddress,
    privateRenter,
):
    data = eth_abi.encode_abi(
        [
            "uint256",
            "uint256",
            "uint256",
            "uint256",
            "address",
            "address",
        ],
        (
            1,
            maxTimeDuration,
            pricePerSecond,
            paymentTokenId,
            paymentTokenAddress,
            privateRenter,
        ),
    ).hex()
    token.safeTransferFrom(user, rentable, tokenId, data, {"from": user})


def main():
    dev = accounts.load("rentable-deployer")
    testNFT = TestNFT.at("0xF88C792bba0D3eA1F4ef6787b9235D65AC71785c")
    rentable = "0xC3f747a87D01b35c6A6eac7844cDf91189438fE9"

    startId = 1
    endId = 51

    day = 24 * 60 * 60
    maxTimeDurationLow = 3 * day
    maxTimeDurationHigh = 15 * day
    timeStep = day / 2

    eth = 1e18
    minPrice = int(0.1 * eth / day)
    maxPrice = int(5 * eth / day)
    priceStep = int(0.2 * eth / day)

    for c in range(startId, endId):
        print(c)
        maxTimeDuration = random.randrange(
            maxTimeDurationLow, maxTimeDurationHigh, timeStep
        )
        pricePerSecond = random.randrange(minPrice, maxPrice, priceStep)
        paymentTokenId = 0
        paymentTokenAddress = "0x0000000000000000000000000000000000000000"
        privateRenter = "0x0000000000000000000000000000000000000000"
        listOnMarket(
            dev,
            testNFT,
            rentable,
            c,
            maxTimeDuration,
            pricePerSecond,
            paymentTokenId,
            paymentTokenAddress,
            privateRenter,
        )
