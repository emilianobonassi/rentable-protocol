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
    renter = accounts[1]

    tokenId = 123
    testNFT.mint(user, tokenId, {"from": user})
    testNFT.mint(user, tokenId + 1, {"from": user})
    testNFT.mint(user, tokenId + 2, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})
    testNFT.approve(rentable, tokenId + 1, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})
    rentable.deposit(testNFT, tokenId + 1, {"from": user})

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

    rentable.createOrUpdateRentalConditions(
        testNFT,
        tokenId + 1,
        paymentToken,
        paymentTokenId,
        maxTimeDuration,
        pricePerSecond,
        address0,
        {"from": user},
    )

    rentalDuration = 70  # seconds
    value = "0.07 ether"

    depositAndApprove(
        renter, rentable, value, paymentToken, paymentTokenId, weth, dummy1155
    )

    rentable.rent(testNFT, tokenId, rentalDuration, {"from": renter, "value": value})

    rentable.SCRAM({"from": operator})

    assert rentable.paused() == True

    # Test everything fallback on emergency implementation

    with brownie.reverts("Emergency in place"):
        rentable.deposit(testNFT, tokenId, {"from": user})

    with brownie.reverts("Emergency in place"):
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

    with brownie.reverts("Emergency in place"):
        rentable.deleteRentalConditions(testNFT, tokenId, {"from": user})

    with brownie.reverts("Emergency in place"):
        rentable.depositAndList(
            testNFT,
            tokenId,
            paymentToken,
            paymentTokenId,
            maxTimeDuration,
            pricePerSecond,
            address0,
            {"from": user},
        )

    with brownie.reverts("Emergency in place"):
        rentable.withdraw(testNFT, tokenId, {"from": user})

    with brownie.reverts("Emergency in place"):
        rentable.expireRental(testNFT, tokenId, {"from": user})

    with brownie.reverts("Emergency in place"):
        rentable.expireRentals([testNFT], [tokenId], {"from": user})

    with brownie.reverts("Emergency in place"):
        orentable.transferFrom(user, operator, tokenId, {"from": user})

    with brownie.reverts("Emergency in place"):
        wrentable.transferFrom(renter, operator, tokenId, {"from": renter})

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
