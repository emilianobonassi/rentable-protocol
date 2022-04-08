import click

from brownie import (
    accounts,
    Rentable,
    ORentable,
    WRentable,
    TestNFT,
    ImmutableAdminTransparentUpgradeableProxy,
    ImmutableAdminUpgradeableBeaconProxy,
    history,
    project,
)

oz = project.load("./lib/openzeppelin-contracts")
UpgradeableBeacon = oz.UpgradeableBeacon
ProxyAdmin = oz.ProxyAdmin


def main():
    dev = accounts.load("rentable-deployer")
    governance = dev
    operator = dev
    feeCollector = dev

    click.echo(f"You are using: 'dev' [{dev.address}]")

    testNFT = TestNFT.deploy({"from": dev})
    eth = "0x0000000000000000000000000000000000000000"

    proxyAdmin = ProxyAdmin.deploy({"from": dev})
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

    orentableLogic = ORentable.deploy(testNFT, eth, eth, {"from": dev})
    obeacon = UpgradeableBeacon.deploy(orentableLogic, {"from": dev})
    oproxy = ImmutableAdminUpgradeableBeaconProxy.deploy(
        obeacon,
        proxyAdmin,
        orentableLogic.initialize.encode_input(testNFT, governance, r),
        {"from": dev},
    )

    o = oproxy.address
    ImmutableAdminUpgradeableBeaconProxy.remove(oproxy)  # otw direct cast not work

    orentable = ORentable.at(o, dev)

    r.setORentable(testNFT, orentable)

    wrentableLogic = WRentable.deploy(testNFT, eth, eth, {"from": dev})
    wbeacon = UpgradeableBeacon.deploy(wrentableLogic, {"from": dev})
    wproxy = ImmutableAdminUpgradeableBeaconProxy.deploy(
        wbeacon,
        proxyAdmin,
        wrentableLogic.initialize.encode_input(testNFT, governance, r),
        {"from": dev},
    )

    w = wproxy.address
    ImmutableAdminUpgradeableBeaconProxy.remove(wproxy)  # otw direct cast not work

    wrentable = WRentable.at(w, dev)

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
               TestNFT: {testNFT.address}
               OBeacon: {obeacon.address}
             ORentable: {orentable.address}
               WBeacon: {wbeacon.address}
             WRentable: {wrentable.address}
              Rentable: {r.address}
         RentableLogic: {rLogic.address}
            ProxyAdmin: {proxyAdmin.address}
              TotalGas: {totalGasUsed}
    """
    )
