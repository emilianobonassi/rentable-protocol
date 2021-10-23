
import click

from brownie import accounts, network, Rentable, WETH9, ORentable, YRentable, WRentable, TestNFT

def main():
    dev = accounts[0]
    click.echo(f"You are using: 'dev' [{dev.address}]")

    weth = WETH9.deploy({"from": dev})
    testNFT = TestNFT.deploy({"from": dev})

    orentable = ORentable.deploy(testNFT, {"from": dev})
    yrentable = YRentable.deploy({"from": dev})
    wrentable = WRentable.deploy(testNFT, {"from": dev})

    n = Rentable.deploy({"from": dev})

    n.setORentable(testNFT, orentable)
    orentable.setMinter(n)

    n.setYToken(yrentable)
    yrentable.setMinter(n)

    wrentable.setRentable(n)
    n.setWRentable(testNFT, wrentable)

    click.echo(
        f"""
    Rentable Deployment Parameters
                 Owner: {dev.address}
                  WETH: {weth.address}
               TestNFT: {testNFT.address}
             ORentable: {orentable.address}
             YRentable: {yrentable.address}
 WRentable for TestNFT: {wrentable.address}
              Rentable: {n.address}
    """
    )