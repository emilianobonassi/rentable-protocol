import click

from brownie import (
    accounts,
    Rentable,
    ORentable,
    WRentable,
    TestNFT,
    EmergencyImplementation,
    ProxyFactoryInitializable,
    history,
)


def main():
    dev = accounts.load("rentable-deployer")
    governance = dev
    operator = dev
    feeCollector = dev

    click.echo(f"You are using: 'dev' [{dev.address}]")

    testNFT = TestNFT.deploy({"from": dev})
    eth = "0x0000000000000000000000000000000000000000"

    proxyFactoryInitializable = ProxyFactoryInitializable.deploy({"from": dev})

    orentable = ORentable.deploy(testNFT, {"from": dev})
    wrentable = WRentable.deploy(testNFT, {"from": dev})

    emergencyImplementation = EmergencyImplementation.deploy({"from": dev})

    r = Rentable.deploy(dev, operator, emergencyImplementation, {"from": dev})

    r.enableAllowlist()

    r.enablePaymentToken(eth)
    r.setFeeCollector(feeCollector)

    orentable.setRentable(r)
    r.setORentable(testNFT, orentable)

    wrentable.setRentable(r)
    r.setWRentable(testNFT, wrentable)

    totalGasUsed = 0
    for tx in history:
        totalGasUsed += tx.gas_used

    click.echo(
        f"""
    Rentable Deployment Parameters
              Deployer: {dev.address}
            Governance: {governance}
              Operator: {operator}
          FeeCollector: {feeCollector}
          ProxyFactory: {proxyFactoryInitializable.address}
               TestNFT: {testNFT.address}
             ORentable: {orentable.address}
             WRentable: {wrentable.address}
              Rentable: {r.address}
              TotalGas: {totalGasUsed}
    """
    )
