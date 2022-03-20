import pytest
from utils import address0

MINIMAL = False


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
def dummy1155(DummyERC1155, deployer):
    yield DummyERC1155.deploy({"from": deployer})


@pytest.fixture
def orentable(deployer, ORentable, testNFT):
    yield ORentable.deploy(testNFT, {"from": deployer})


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
    params=[["0 ether", 0]]
    if MINIMAL
    else [["0 ether", 0], ["0.01 ether", 0], ["0 ether", 500], ["0.01 ether", 500]],
    ids=["no-fees"]
    if MINIMAL
    else ["no-fees", "fixed-fee-no-fee", "no-fixed-fee-fee", "fixed-fee-fee"],
)
def rentableWithFees(
    rentable,
    request,
):
    rentable.setFixedFee(request.param[0])
    rentable.setFee(request.param[1])

    yield rentable


@pytest.fixture
def rentable(
    deployer,
    governance,
    operator,
    emergencyImplementation,
    Rentable,
    ORentable,
    WRentable,
    orentable,
    wrentable,
    testNFT,
    feeCollector,
    weth,
    dummy1155,
    testLand,
    decentralandCollectionLibrary,
    proxyFactoryInitializable,
):
    n = Rentable.deploy(
        governance, operator, emergencyImplementation, {"from": governance}
    )

    n.setORentable(testNFT, orentable)
    orentable.setRentable(n)

    wrentable.setRentable(n)
    n.setWRentable(testNFT, wrentable)

    n.enablePaymentToken(address0)
    n.enablePaymentToken(weth.address)
    n.enable1155PaymentToken(dummy1155.address)

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

    n.setFeeCollector(feeCollector)

    yield n


@pytest.fixture
def testNFT(deployer, TestNFT):
    yield TestNFT.deploy({"from": deployer})


@pytest.fixture(params=["ETH"] if MINIMAL else ["ETH", "WETH", "DUMMY1155"])
def paymentToken(request, weth, dummy1155):
    if request.param == "ETH":
        return address0
    elif request.param == "WETH":
        return weth.address
    elif request.param == "DUMMY1155":
        return dummy1155.address
    else:
        raise Exception("paymentToken not supported")


@pytest.fixture
def paymentTokenId(request, paymentToken, dummy1155):
    if paymentToken == dummy1155.address:
        return dummy1155.TOKEN2()
    else:
        return 0


@pytest.fixture(autouse=True)
def shared_setup(fn_isolation):
    pass
