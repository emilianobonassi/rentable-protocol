import click

from brownie import (
    accounts,
    Rentable,
    ORentable,
    YRentable,
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

    yrentable = YRentable.deploy({"from": dev})

    orentable = ORentable.deploy(testNFT, {"from": dev})
    assert orentable.getWrapped() == testNFT.address
    wrentable = WRentable.deploy(testNFT, {"from": dev})
    assert wrentable.getWrapped() == testNFT.address

    emergencyImplementation = EmergencyImplementation.deploy({"from": dev})

    r = Rentable.deploy(dev, operator, emergencyImplementation, {"from": dev})

    assert r.emergencyImplementation() == emergencyImplementation.address

    r.enableAllowlist()

    r.enablePaymentToken(eth)
    assert r.paymentTokenAllowlist(eth) == True
    r.setFeeCollector(feeCollector)
    assert r.getFeeCollector() == feeCollector

    r.setYToken(yrentable)
    yrentable.setMinter(r)
    assert yrentable.getMinter() == r.address

    orentable.setRentable(r)
    assert orentable.getRentable() == r.address
    assert orentable.getMinter() == r.address
    r.setORentable(testNFT, orentable)
    assert r.getORentable(testNFT) == orentable.address

    wrentable.setRentable(r)
    assert wrentable.getRentable() == r.address
    assert wrentable.getMinter() == r.address
    r.setWRentable(testNFT, wrentable)
    # assert r.getWRentable(testNFT) == wrentable.address

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
             YRentable: {yrentable.address}
             ORentable: {orentable.address}
             WRentable: {wrentable.address}
              Rentable: {r.address}
              TotalGas: {totalGasUsed}
    """
    )
