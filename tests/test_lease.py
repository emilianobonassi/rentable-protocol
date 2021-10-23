import brownie

def test_create_lease(rentable, testNFT, accounts, paymentToken):
    user = accounts[0]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})

    maxTimeDuration = 1000 # blocks
    pricePerBlock = 0.001 * (10 ** 18)

    rentable.createOrUpdateLeaseConditions(
        testNFT, tokenId, paymentToken, maxTimeDuration, pricePerBlock, {"from": user}
    )

    # Test lease created correctly
    lease = rentable.leasesConditions(testNFT, tokenId).dict()
    assert lease["maxTimeDuration"] == maxTimeDuration
    assert lease["pricePerBlock"] == pricePerBlock
    assert lease["paymentTokenAddress"] == paymentToken

def test_delete_lease(rentable, testNFT, accounts, paymentToken):
    user = accounts[0]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})

    maxTimeDuration = 1000  # 7 days
    pricePerBlock = 0.001 * (10 ** 18)

    rentable.createOrUpdateLeaseConditions(
        testNFT, tokenId, paymentToken, maxTimeDuration, pricePerBlock, {"from": user}
    )
    rentable.deleteLeaseConditions(testNFT, tokenId, {"from": user})

    # Test lease created correctly
    lease = rentable.leasesConditions(testNFT, tokenId).dict()

    assert lease["maxTimeDuration"] == 0


def test_update_lease(rentable, testNFT, accounts, paymentToken):
    user = accounts[0]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})

    maxTimeDuration = 1000  # blocks
    pricePerBlock = 0.001 * (10 ** 18)

    rentable.createOrUpdateLeaseConditions(
        testNFT, tokenId, paymentToken, maxTimeDuration, pricePerBlock, {"from": user}
    )

    # Test lease created correctly
    lease = rentable.leasesConditions(testNFT, tokenId).dict()
    assert lease["maxTimeDuration"] == maxTimeDuration
    assert lease["pricePerBlock"] == pricePerBlock
    assert lease["paymentTokenAddress"] == paymentToken

    maxTimeDuration = 800  # blocks
    pricePerBlock = 0.8 * (10 ** 18)

    rentable.createOrUpdateLeaseConditions(
        testNFT, tokenId, paymentToken, maxTimeDuration, pricePerBlock, {"from": user}
    )

    # Test lease update correctly
    lease = rentable.leasesConditions(testNFT, tokenId).dict()
    assert lease["maxTimeDuration"] == maxTimeDuration
    assert lease["pricePerBlock"] == pricePerBlock
    assert lease["paymentTokenAddress"] == paymentToken


def test_subscribe_lease(rentable, testNFT, paymentToken, yrentable, accounts, wrentable, chain, weth, feeCollector):
    user = accounts[0]
    subscriber = accounts[1]
    feeCollector = accounts.at(rentable.getFeeCollector())

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})

    maxTimeDuration = 1000  # 7 days
    pricePerBlock = 0.001 * (10 ** 18)

    rentable.createOrUpdateLeaseConditions(
        testNFT, tokenId, paymentToken, maxTimeDuration, pricePerBlock, {"from": user}
    )

    # Test subscribtion
    subscriptionDuration = 700 # blocks
    value = "0.7 ether"

    preBalanceFeeCollector = weth.balanceOf(feeCollector) if paymentToken == weth.address else feeCollector.balance()

    if (paymentToken == weth.address):
        weth.deposit({"from": subscriber, "value": value})
        weth.approve(rentable, value, {"from": subscriber})
        preBalanceSubscriber = weth.balanceOf(subscriber)

        tx = rentable.createLease(testNFT, tokenId, subscriptionDuration, {"from": subscriber})
    elif (paymentToken == "0x0000000000000000000000000000000000000000"):
        preBalanceSubscriber = subscriber.balance()
        tx = rentable.createLease(testNFT, tokenId, subscriptionDuration, {"from": subscriber, "value": value})

    postBalanceSubscriber = weth.balanceOf(subscriber) if paymentToken == weth.address else subscriber.balance()
    rentPayed = preBalanceSubscriber-postBalanceSubscriber

    evt = tx.events['Rent']

    assert evt['from'] == user
    assert evt['to'] == subscriber
    assert evt['tokenAddress'] == testNFT.address
    assert evt['tokenId'] == tokenId

    lease = rentable.currentLeases(testNFT, tokenId).dict()

    assert lease["eta"] == tx.block_number + subscriptionDuration
    balanceToCheck = (weth.balanceOf(rentable) if paymentToken == weth.address else rentable.balance())
    totalFeesToPay = (rentPayed - rentable.getFixedFee())*rentable.getFee()/rentable.BASE_FEE()
    assert lease["qtyToPullRemaining"] == (
        rentPayed - rentable.getFixedFee() - totalFeesToPay
    )
    assert balanceToCheck == lease["qtyToPullRemaining"] + lease["feesToPullRemaining"]
    assert lease["feesToPullRemaining"] == totalFeesToPay
    assert rentable.getFixedFee() == (weth.balanceOf(feeCollector) if paymentToken == weth.address else feeCollector.balance()) - preBalanceFeeCollector

    assert lease["lastUpdated"] == tx.block_number

    assert yrentable.ownerOf(1) == user.address

    assert wrentable.ownerOf(tokenId) == subscriber.address

    chain.mine(subscriptionDuration + 1)

    assert wrentable.ownerOf(tokenId) == "0x0000000000000000000000000000000000000000"

def test_subscribe_lease_via_depositAndList(rentable, testNFT, paymentToken, yrentable, accounts, wrentable, chain, weth, feeCollector):
    user = accounts[0]
    subscriber = accounts[1]
    feeCollector = accounts.at(rentable.getFeeCollector())

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    maxTimeDuration = 1000  # blocks
    pricePerBlock = 0.001 * (10 ** 18)

    rentable.depositAndList(testNFT, tokenId, paymentToken, maxTimeDuration, pricePerBlock, {"from": user})

    # Test subscribtion
    subscriptionDuration = 800 # blocks
    value = "0.8 ether"

    preBalanceFeeCollector = weth.balanceOf(feeCollector) if paymentToken == weth.address else feeCollector.balance()

    if (paymentToken == weth.address):
        weth.deposit({"from": subscriber, "value": value})
        weth.approve(rentable, value, {"from": subscriber})
        preBalanceSubscriber = weth.balanceOf(subscriber)

        tx = rentable.createLease(testNFT, tokenId, subscriptionDuration, {"from": subscriber})
    elif (paymentToken == "0x0000000000000000000000000000000000000000"):
        preBalanceSubscriber = subscriber.balance()
        tx = rentable.createLease(testNFT, tokenId, subscriptionDuration, {"from": subscriber, "value": value})

    postBalanceSubscriber = weth.balanceOf(subscriber) if paymentToken == weth.address else subscriber.balance()
    rentPayed = preBalanceSubscriber-postBalanceSubscriber

    evt = tx.events['Rent']

    assert evt['from'] == user
    assert evt['to'] == subscriber
    assert evt['tokenAddress'] == testNFT.address
    assert evt['tokenId'] == tokenId

    lease = rentable.currentLeases(testNFT, tokenId).dict()

    assert lease["eta"] == tx.block_number + subscriptionDuration
    balanceToCheck = (weth.balanceOf(rentable) if paymentToken == weth.address else rentable.balance())
    totalFeesToPay = (rentPayed - rentable.getFixedFee())*rentable.getFee()/rentable.BASE_FEE()
    assert lease["qtyToPullRemaining"] == (
        rentPayed - rentable.getFixedFee() - totalFeesToPay
    )
    assert balanceToCheck == lease["qtyToPullRemaining"] + lease["feesToPullRemaining"]
    assert lease["feesToPullRemaining"] == totalFeesToPay
    assert rentable.getFixedFee() == (weth.balanceOf(feeCollector) if paymentToken == weth.address else feeCollector.balance()) - preBalanceFeeCollector

    assert lease["lastUpdated"] == tx.block_number

    assert yrentable.ownerOf(1) == user.address

    assert wrentable.ownerOf(tokenId) == subscriber.address

    chain.mine(subscriptionDuration + 1)

    assert wrentable.ownerOf(tokenId) == "0x0000000000000000000000000000000000000000"

def test_redeem_lease(rentable, testNFT, paymentToken, weth, accounts, chain, feeCollector):
    user = accounts[0]
    subscriber = accounts[1]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})

    maxTimeDuration = 1000  # blocks
    pricePerBlock = int(0.001 * (10 ** 18))

    rentable.createOrUpdateLeaseConditions(
        testNFT, tokenId, paymentToken, maxTimeDuration, pricePerBlock, {"from": user}
    )

    # Create subscribtion
    subscriptionDuration = 800
    value = "0.8 ether"
    txCreate = None
    preBalanceSubscriber = postBalanceSubscriber = 0

    if (paymentToken == weth.address):
        weth.deposit({"from": subscriber, "value": value})
        weth.approve(rentable, value, {"from": subscriber})

        preBalanceSubscriber = weth.balanceOf(subscriber)
        txCreate = rentable.createLease(testNFT, tokenId, subscriptionDuration, {"from": subscriber})
        postBalanceSubscriber = weth.balanceOf(subscriber)

    elif (paymentToken == "0x0000000000000000000000000000000000000000"):
        preBalanceSubscriber = subscriber.balance()
        txCreate = rentable.createLease(testNFT, tokenId, subscriptionDuration, {"from": subscriber, "value": value})
        postBalanceSubscriber = subscriber.balance()

    evt = txCreate.events['Rent']

    assert evt['from'] == user
    assert evt['to'] == subscriber
    assert evt['tokenAddress'] == testNFT.address
    assert evt['tokenId'] == tokenId

    # Redeem collateral after 100 blocks
    totalRedeemed = 0
    totalFeesRedeemed = 0
    time = 100
    chain.mine(time)

    leasePreRedeem = initialLease = rentable.currentLeases(testNFT, tokenId).dict()

    preFeeCollectorBalance = weth.balanceOf(feeCollector) if paymentToken == weth.address else feeCollector.balance()
    preBalance = weth.balanceOf(user) if paymentToken == weth.address else user.balance()
    txRedeem = rentable.redeemLease(1, {"from": user})
    postBalance = weth.balanceOf(user) if paymentToken == weth.address else user.balance()
    postFeeCollectorBalance = weth.balanceOf(feeCollector) if paymentToken == weth.address else feeCollector.balance()

    duration = txRedeem.block_number - txCreate.block_number
    amountToRedeem = leasePreRedeem["qtyToPullRemaining"] * duration // (leasePreRedeem["eta"] - leasePreRedeem["lastUpdated"])
    feesToRedeem = leasePreRedeem["feesToPullRemaining"] * duration // (leasePreRedeem["eta"] - leasePreRedeem["lastUpdated"])

    evt = txRedeem.events['Claim']

    assert evt['who'] == user
    assert evt['tokenAddress'] == testNFT.address
    assert evt['tokenId'] == tokenId
    assert evt['paymentTokenAddress'] == paymentToken
    assert evt['qty'] == amountToRedeem

    assert (postBalance - preBalance) >= amountToRedeem
    totalRedeemed += amountToRedeem
    totalFeesRedeemed += feesToRedeem

    lease = rentable.currentLeases(testNFT, tokenId).dict()

    assert lease["lastUpdated"] == txRedeem.block_number
    assert (
        lease["qtyToPullRemaining"]
        == leasePreRedeem["qtyToPullRemaining"] - amountToRedeem
    )

    assert (postFeeCollectorBalance - preFeeCollectorBalance) == feesToRedeem
    assert (
        lease["feesToPullRemaining"]
        == leasePreRedeem["feesToPullRemaining"] - feesToRedeem
    )

    # Redeem collateral after 100 blocks

    chain.mine(time)

    leasePreRedeem = rentable.currentLeases(testNFT, tokenId).dict()

    preFeeCollectorBalance = weth.balanceOf(feeCollector) if paymentToken == weth.address else feeCollector.balance()
    preBalance = weth.balanceOf(user) if paymentToken == weth.address else user.balance()
    txRedeemNext = rentable.redeemLease(1, {"from": user})
    postBalance = weth.balanceOf(user) if paymentToken == weth.address else user.balance()
    postFeeCollectorBalance = weth.balanceOf(feeCollector) if paymentToken == weth.address else feeCollector.balance()

    duration = txRedeemNext.block_number - txRedeem.block_number
    txRedeem = txRedeemNext
    amountToRedeem = leasePreRedeem["qtyToPullRemaining"] * duration // (leasePreRedeem["eta"] - leasePreRedeem["lastUpdated"])
    feesToRedeem = leasePreRedeem["feesToPullRemaining"] * duration // (leasePreRedeem["eta"] - leasePreRedeem["lastUpdated"])

    evt = txRedeem.events['Claim']

    assert evt['who'] == user
    assert evt['tokenAddress'] == testNFT.address
    assert evt['tokenId'] == tokenId
    assert evt['paymentTokenAddress'] == paymentToken
    assert evt['qty'] == amountToRedeem

    assert (postBalance - preBalance) >= amountToRedeem
    totalRedeemed += amountToRedeem
    totalFeesRedeemed += feesToRedeem

    lease = rentable.currentLeases(testNFT, tokenId).dict()

    assert lease["lastUpdated"] == txRedeem.block_number
    assert (
        lease["qtyToPullRemaining"]
        == leasePreRedeem["qtyToPullRemaining"] - amountToRedeem
    )

    assert (postFeeCollectorBalance - preFeeCollectorBalance) == feesToRedeem
    assert (
        lease["feesToPullRemaining"]
        == leasePreRedeem["feesToPullRemaining"] - feesToRedeem
    )

    # Redeem collateral after all the period day
    time = 2000
    chain.mine(time)

    preFeeCollectorBalance = weth.balanceOf(feeCollector) if paymentToken == weth.address else feeCollector.balance()
    preBalance = weth.balanceOf(user) if paymentToken == weth.address else user.balance()
    txRedeemNext = rentable.redeemLease(1, {"from": user})
    postBalance = weth.balanceOf(user) if paymentToken == weth.address else user.balance()
    postFeeCollectorBalance = weth.balanceOf(feeCollector) if paymentToken == weth.address else feeCollector.balance()

    duration = txRedeemNext.block_number - txRedeem.block_number
    txRedeem = txRedeemNext
    amountToRedeem = initialLease["qtyToPullRemaining"] - totalRedeemed
    feesToRedeem = initialLease["feesToPullRemaining"] - totalFeesRedeemed

    evt = txRedeem.events['Claim']

    assert evt['who'] == user
    assert evt['tokenAddress'] == testNFT.address
    assert evt['tokenId'] == tokenId
    assert evt['paymentTokenAddress'] == paymentToken
    assert evt['qty'] == amountToRedeem

    lease = rentable.currentLeases(testNFT, tokenId).dict()

    assert lease["lastUpdated"] == txRedeemNext.block_number
    assert (
        lease["qtyToPullRemaining"]
        == 0
    )

    assert (postFeeCollectorBalance - preFeeCollectorBalance) == feesToRedeem
    assert (
        lease["feesToPullRemaining"]
        == 0
    )

    evt = txRedeem.events['RentEnds']

    assert evt['from'] == user
    assert evt['to'] == subscriber
    assert evt['tokenAddress'] == testNFT.address
    assert evt['tokenId'] == tokenId

    assert (postBalance - preBalance) >= amountToRedeem
    totalRedeemed += amountToRedeem

    assert 0 == (weth.balanceOf(rentable) if paymentToken == weth.address else rentable.balance())


def test_do_not_withdraw_on_lease(rentable, testNFT, paymentToken, weth, yrentable, accounts, chain):
    user = accounts[0]
    subscriber = accounts[1]

    tokenId = 123

    testNFT.mint(user, tokenId, {"from": user})

    testNFT.approve(rentable, tokenId, {"from": user})

    rentable.deposit(testNFT, tokenId, {"from": user})

    maxTimeDuration = 1000  # blocks
    pricePerBlock = 0.001 * (10 ** 18)

    rentable.createOrUpdateLeaseConditions(
        testNFT, tokenId, paymentToken, maxTimeDuration, pricePerBlock, {"from": user}
    )

    # Test subscribtion
    subscriptionDuration = 400
    value = "0.4 ether"

    if (paymentToken == weth.address):
        weth.deposit({"from": subscriber, "value": value})
        weth.approve(rentable, value, {"from": subscriber})

        tx = rentable.createLease(testNFT, tokenId, subscriptionDuration, {"from": subscriber})
    elif (paymentToken == "0x0000000000000000000000000000000000000000"):
        tx = rentable.createLease(testNFT, tokenId, subscriptionDuration, {"from": subscriber, "value": value})

    evt = tx.events['Rent']

    assert evt['from'] == user
    assert evt['to'] == subscriber
    assert evt['tokenAddress'] == testNFT.address
    assert evt['tokenId'] == tokenId

    with brownie.reverts("Current lease still pending"):
        rentable.withdraw(testNFT, tokenId, {"from": user})

    chain.mine(400 + 1)

    rentable.withdraw(testNFT, tokenId, {"from": user})
