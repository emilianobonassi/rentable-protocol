import click

from brownie import (
    accounts,
    Rentable,
    ORentable,
    YRentable,
    WRentable,
    EmergencyImplementation,
    ProxyFactoryInitializable,
    history,
)


def main():
    dev = accounts.load("dev")
    governance = "0xC08618375bb20ac1C4BB806Baa027a4362156fE6"
    operator = "0x49941c694693371894d6DCc1AbDbC91A7395b703"
    feeCollector = "0xa55D576DE85dA4295aBc1E2BEa5d5c77Fe189205"

    click.echo(f"You are using: 'dev' [{dev.address}]")

    meebits = "0x7Bd29408f11D2bFC23c34f18275bBf23bB716Bc7"
    eth = "0x0000000000000000000000000000000000000000"

    proxyFactoryInitializable = ProxyFactoryInitializable.deploy({"from": dev})

    yrentable = YRentable.deploy({"from": dev})

    orentable = ORentable.deploy(meebits, {"from": dev})
    assert orentable.getWrapped() == meebits
    wrentable = WRentable.deploy(meebits, {"from": dev})
    assert wrentable.getWrapped() == meebits

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
    yrentable.transferOwnership(governance)
    assert yrentable.owner() == governance

    orentable.setRentable(r)
    assert orentable.getRentable() == r.address
    assert orentable.getMinter() == r.address
    orentable.transferOwnership(governance)
    assert orentable.owner() == governance
    r.setORentable(meebits, orentable)
    assert r.getORentable(meebits) == orentable.address

    wrentable.setRentable(r)
    assert wrentable.getRentable() == r.address
    assert wrentable.getMinter() == r.address
    wrentable.transferOwnership(governance)
    assert wrentable.owner() == governance
    r.setWRentable(meebits, wrentable)
    assert r.getWRentable(meebits) == wrentable.address

    r.setGovernance(governance)
    assert r.pendingGovernance() == governance
    assert r.operator() == operator

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
               Meebits: {meebits}
             YRentable: {yrentable.address}
             ORentable: {orentable.address}
             WRentable: {wrentable.address}
              Rentable: {r.address}
              TotalGas: {totalGasUsed}
    """
    )
