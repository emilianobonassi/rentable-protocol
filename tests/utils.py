address0 = "0x0000000000000000000000000000000000000000"


def depositAndApprove(
    account, toApprove, value, paymentToken, paymentTokenId, weth, dummy1155
):
    if paymentToken == weth.address:
        weth.deposit({"from": account, "value": value})
        weth.approve(toApprove, value, {"from": account})
    elif paymentToken == dummy1155.address:
        dummy1155.deposit(paymentTokenId, {"from": account, "value": value})
        dummy1155.setApprovalForAll(toApprove, True, {"from": account})


def getBalance(account, paymentToken, paymentTokenId, weth, dummy1155):
    if paymentToken == weth.address:
        return weth.balanceOf(account)
    elif paymentToken == dummy1155.address:
        return dummy1155.balanceOf(account, paymentTokenId)
    else:
        return account.balance()
