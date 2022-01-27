import click

from brownie import accounts, network, TestNFT


def main():
    dev = accounts[0]
    click.echo(f"You are using: 'dev' [{dev.address}]")

    testNFT = TestNFT.deploy({"from": dev})

    testNFTAddress = click.prompt(
        "NFT smart contract address?",
        default=testNFT.address,
    )

    testNFT = TestNFT.at(testNFTAddress)

    to = click.prompt(
        "Receiver address?",
        default=dev,
    )

    tokenId = click.prompt(
        "TokenId to mint?",
        default=0,
    )

    testNFT.mint(to, tokenId, {"from": dev})

    click.echo(
        f"""
Rentable Deployment Parameters
           TestNFT: {testNFTAddress}
          Receiver: {to}
           TokenId: {tokenId}  
    """
    )
