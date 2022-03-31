import click

from brownie import (
    accounts,
    Rentable,
    ORentable,
    WRentable,
    TestNFT,
    ImmutableProxyAdmin,
    ImmutableAdminTransparentUpgradeableProxy,
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

    proxyAdmin = ImmutableProxyAdmin.deploy({"from": dev})
    rLogic = Rentable.deploy(governance, operator, {"from": dev})
    rLogic.SCRAM()

    proxy = ImmutableAdminTransparentUpgradeableProxy.deploy(
        rLogic,
        proxyAdmin,
        rLogic.initialize.encode_input(governance, operator),
        {"from": dev},
    )

    r = proxy.address
    ImmutableAdminTransparentUpgradeableProxy.remove(proxy)

    r = Rentable.at(r, dev)

    assert proxyAdmin.getProxyImplementation(r) == rLogic.address

    proxyFactoryInitializable = ProxyFactoryInitializable.deploy({"from": dev})

    orentable = ORentable.deploy(testNFT, governance, r, {"from": dev})
    r.setORentable(testNFT, oßrentable)
    wrentable = WRentable.deploy(testNFT, governance, r, {"from": dev})
    r.setWRentable(testNFT, wrentable)

    r.enablePaymentToken(eth)
    r.setFeeCollector(feeCollector)

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
         RentableLogic: {rLogic.address}
            ProxyAdmin: {proxyAdmin.address}
              TotalGas: {totalGasUsed}
    """
    )
