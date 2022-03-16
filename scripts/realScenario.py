import click
import eth_abi

from brownie import (
    accounts,
    Rentable,
    ORentable,
    YRentable,
    WRentable,
    interface,
    chain,
)


def deposit1tx(
    rentable, nft, depositor, tokenId, maxTimeDuration, pricePerBlock, paymentToken
):
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

    return nft.safeTransferFrom(depositor, rentable, tokenId, data, {"from": depositor})


def main():
    dev = accounts[0]
    click.echo(f"You are using: 'dev' [{dev.address}]")

    lootContract = interface.IERC721("0x13a48f723f4AD29b6da6e7215Fe53172C027d98f")
    landContract = interface.IERC721("0x50f5474724e0Ee42D9a4e711ccFB275809Fd6d4a")

    # Rentable deployment

    n = Rentable.deploy({"from": dev})

    yrentable = YRentable.deploy({"from": dev})
    n.setYToken(yrentable)
    yrentable.setMinter(n)

    orentableLoot = ORentable.deploy(lootContract, {"from": dev})
    n.setORentable(lootContract, orentableLoot)
    orentableLoot.setMinter(n)

    orentableLand = ORentable.deploy(landContract, {"from": dev})
    n.setORentable(landContract, orentableLand)
    orentableLand.setMinter(n)

    wrentableLoot = WRentable.deploy(lootContract, {"from": dev})
    wrentableLoot.setRentable(n)
    n.setWRentable(lootContract, wrentableLoot)

    wrentableLand = WRentable.deploy(landContract, {"from": dev})
    wrentableLand.setRentable(n)
    n.setWRentable(landContract, wrentableLand)

    # Move some Loots and lands to two depositors

    depositorA = accounts[1]
    depositorB = accounts[2]

    LootsIds = [8454, 9671, 9314, 9779, 8419]

    for lid in LootsIds:
        click.echo(f""" LootId: {lid} """)
        effectiveOwner = accounts.at(lootContract.ownerOf(lid), force=True)
        lootContract.transferFrom(
            effectiveOwner, depositorA, lid, {"from": effectiveOwner}
        )

    landIds = [92414, 68621, 42985, 99011, 104915]

    for lid in landIds:
        click.echo(f""" LandId: {lid} """)
        effectiveOwner = accounts.at(landContract.ownerOf(lid), force=True)
        landContract.transferFrom(
            effectiveOwner, depositorB, lid, {"from": effectiveOwner}
        )

    # Deposit and list

    deposits = [
        {
            "tokenAddress": lootContract,
            "tokenId": 8454,
            "user": depositorA,
            "maxTimeDuration": 500,
            "pricePerBlock": 1 * 1e15,
            "paymentToken": "0x0000000000000000000000000000000000000000",
        },
        {
            "tokenAddress": lootContract,
            "tokenId": 9671,
            "user": depositorA,
            "maxTimeDuration": 1000,
            "pricePerBlock": 2 * 1e15,
            "paymentToken": "0x0000000000000000000000000000000000000000",
        },
        {
            "tokenAddress": lootContract,
            "tokenId": 8419,
            "user": depositorA,
            "maxTimeDuration": 800,
            "pricePerBlock": 3 * 1e15,
            "paymentToken": "0x0000000000000000000000000000000000000000",
        },
        {
            "tokenAddress": lootContract,
            "tokenId": 9314,
            "user": depositorA,
            "maxTimeDuration": 700,
            "pricePerBlock": 5 * 1e15,
            "paymentToken": "0x0000000000000000000000000000000000000000",
        },
        {
            "tokenAddress": lootContract,
            "tokenId": 9779,
            "user": depositorA,
            "maxTimeDuration": 1500,
            "pricePerBlock": 4 * 1e15,
            "paymentToken": "0x0000000000000000000000000000000000000000",
        },
        {
            "tokenAddress": landContract,
            "tokenId": 92414,
            "user": depositorB,
            "maxTimeDuration": 1300,
            "pricePerBlock": 1 * 1e15,
            "paymentToken": "0x0000000000000000000000000000000000000000",
        },
        {
            "tokenAddress": landContract,
            "tokenId": 68621,
            "user": depositorB,
            "maxTimeDuration": 1300,
            "pricePerBlock": 1 * 1e15,
            "paymentToken": "0x0000000000000000000000000000000000000000",
        },
        {
            "tokenAddress": landContract,
            "tokenId": 42985,
            "user": depositorB,
            "maxTimeDuration": 1300,
            "pricePerBlock": 1 * 1e15,
            "paymentToken": "0x0000000000000000000000000000000000000000",
        },
        {
            "tokenAddress": landContract,
            "tokenId": 99011,
            "user": depositorB,
            "maxTimeDuration": 1300,
            "pricePerBlock": 1 * 1e15,
            "paymentToken": "0x0000000000000000000000000000000000000000",
        },
        {
            "tokenAddress": landContract,
            "tokenId": 104915,
            "user": depositorB,
            "maxTimeDuration": 1300,
            "pricePerBlock": 1 * 1e15,
            "paymentToken": "0x0000000000000000000000000000000000000000",
        },
    ]

    for d in deposits:
        deposit1tx(
            n,
            d["tokenAddress"],
            d["user"],
            d["tokenId"],
            d["maxTimeDuration"],
            d["pricePerBlock"],
            d["paymentToken"],
        )

    # Rent

    renterA = accounts[3]
    renterB = accounts[4]

    n.createLease(lootContract, 9314, 300, {"from": renterA, "value": "1 ether"})
    n.createLease(landContract, 104915, 500, {"from": renterA, "value": "1 ether"})
    n.createLease(lootContract, 9671, 400, {"from": renterB, "value": "1 ether"})

    # To be expired available to fully claim

    n.createLease(landContract, 42985, 5, {"from": renterA, "value": "1 ether"})
    n.createLease(landContract, 99011, 10, {"from": renterB, "value": "1 ether"})
    chain.mine(12)
    n.redeemLease(4, {"from": depositorB})
    n.redeemLease(5, {"from": depositorB})

    click.echo(
        f"""
    Rentable Deployment Parameters
             Owner: {dev.address}
        DepositorA: {depositorA.address}
        DepositorB: {depositorB.address}
           RenterA: {renterA.address}
           RenterB: {renterB.address}
  ORentable(Loots): {orentableLoot.address}
   ORentable(Land): {orentableLand.address}
  WRentable(Loots): {wrentableLoot.address}
   WRentable(Land): {wrentableLand.address}
         YRentable: {yrentable.address}
          Rentable: {n.address}
  Deployment block: {n.tx.block_number}
    """
    )
