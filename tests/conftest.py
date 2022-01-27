import pytest


@pytest.fixture
def deployer(accounts):
    yield accounts[2]


@pytest.fixture
def feeCollector(accounts):
    yield accounts[4]


@pytest.fixture
def governance(accounts):
    yield accounts[6]


@pytest.fixture
def operator(accounts):
    yield accounts[7]


@pytest.fixture
def weth(WETH9, deployer):
    yield WETH9.deploy({"from": deployer})


@pytest.fixture
def orentable(deployer, ORentable, testNFT):
    yield ORentable.deploy(testNFT, {"from": deployer})


@pytest.fixture
def yrentable(deployer, YRentable):
    yield YRentable.deploy({"from": deployer})


@pytest.fixture
def wrentable(deployer, WRentable, testNFT):
    yield WRentable.deploy(testNFT, {"from": deployer})


@pytest.fixture
def emergencyImplementation(deployer, EmergencyImplementation):
    yield EmergencyImplementation.deploy({"from": deployer})


@pytest.fixture
def dummylib(deployer, DummyCollectionLibrary, eternalstorage):
    yield DummyCollectionLibrary.deploy(eternalstorage, {"from": deployer})


@pytest.fixture(scope="function", autouse=True)
def eternalstorage(deployer, EternalStorage):
    yield EternalStorage.deploy({"from": deployer})


@pytest.fixture
def testLand(deployer, TestLand):
    yield TestLand.deploy({"from": deployer})


@pytest.fixture
def decentralandCollectionLibrary(deployer, DecentralandCollectionLibrary):
    yield DecentralandCollectionLibrary.deploy({"from": deployer})


@pytest.fixture
def proxyFactoryInitializable(deployer, ProxyFactoryInitializable):
    yield ProxyFactoryInitializable.deploy({"from": deployer})


@pytest.fixture(
    params=[["0 ether", 0], ["0.01 ether", 0], ["0 ether", 500], ["0.01 ether", 500]],
    ids=["no-fees", "fixed-fee-no-fee", "no-fixed-fee-fee", "fixed-fee-fee"],
)
def rentable(
    deployer,
    governance,
    operator,
    emergencyImplementation,
    Rentable,
    ORentable,
    WRentable,
    orentable,
    yrentable,
    wrentable,
    testNFT,
    feeCollector,
    weth,
    testLand,
    decentralandCollectionLibrary,
    proxyFactoryInitializable,
    request,
):
    n = Rentable.deploy(
        governance, operator, emergencyImplementation, {"from": governance}
    )

    n.setYToken(yrentable)
    yrentable.setMinter(n)

    n.setORentable(testNFT, orentable)
    orentable.setRentable(n)

    wrentable.setRentable(n)
    n.setWRentable(testNFT, wrentable)

    n.enablePaymentToken("0x0000000000000000000000000000000000000000")
    n.enablePaymentToken(weth.address)

    # Decentraland init
    data = orentable.init.encode_input(testLand, deployer)
    tx = proxyFactoryInitializable.deployMinimal(orentable, data, {"from": deployer})
    od = ORentable.at((tx.events["ProxyCreated"]["proxy"]), deployer)
    od = ORentable.deploy(testLand, {"from": deployer})
    od.setRentable(n)
    n.setORentable(testLand, od)

    data = wrentable.init.encode_input(testLand, deployer)
    tx = proxyFactoryInitializable.deployMinimal(wrentable, data, {"from": deployer})
    od = WRentable.at((tx.events["ProxyCreated"]["proxy"]), deployer)
    wd = WRentable.deploy(testLand, {"from": deployer})
    wd.setRentable(n)
    n.setWRentable(testLand, wd)
    n.setLibrary(testLand, decentralandCollectionLibrary)

    n.setFixedFee(request.param[0])
    n.setFee(request.param[1])
    n.setFeeCollector(feeCollector)

    yield n


@pytest.fixture
def testNFT(deployer, TestNFT):
    yield TestNFT.deploy({"from": deployer})


@pytest.fixture(
    params=[
        "ETH",
        "WETH",
    ]
)
def paymentToken(request, weth):
    if request.param == "ETH":
        return "0x0000000000000000000000000000000000000000"
    elif request.param == "WETH":
        return weth.address
    else:
        raise Exception("paymentToken not supported")


@pytest.fixture(autouse=True)
def shared_setup(fn_isolation):
    pass
