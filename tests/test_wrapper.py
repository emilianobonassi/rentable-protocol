import brownie


def test_wrapper(testNFT, deployer, ERC721ReadOnlyProxy, accounts):
    testNFT.mint(deployer, 123, {"from": deployer})

    prefix = "z"
    wrapper = ERC721ReadOnlyProxy.deploy(testNFT, prefix, {"from": deployer})

    assert wrapper.getWrapped() == testNFT.address

    assert wrapper.symbol() == prefix + testNFT.symbol()
    assert wrapper.name() == prefix + testNFT.name()
    assert wrapper.tokenURI(123) == testNFT.tokenURI(123)

    minter = accounts[0]
    user = accounts[1]
    wrapper.setMinter(minter)
    assert wrapper.getMinter() == minter

    tokenId = 50
    wrapper.mint(user, tokenId, {"from": minter})
    assert wrapper.ownerOf(tokenId) == user

    with brownie.reverts("Only minter"):
        wrapper.mint(user, tokenId + 1, {"from": user})

    with brownie.reverts("Only minter"):
        wrapper.burn(tokenId, {"from": user})

    wrapper.burn(tokenId, {"from": minter})
    with brownie.reverts("ERC721: owner query for nonexistent token"):
        wrapper.ownerOf(tokenId)


def test_wrappers_proxy_init(
    TestNFT,
    ERC721ReadOnlyProxyInitializable,
    proxyFactoryInitializable,
    deployer,
    accounts,
):

    t1 = TestNFT.deploy({"from": deployer})

    t2 = TestNFT.deploy({"from": deployer})

    owner = accounts[4]

    logic = ERC721ReadOnlyProxyInitializable.deploy(t1, "w", {"from": deployer})

    proxyPrefix = "j"
    data = logic.init.encode_input(t2, proxyPrefix, owner)

    tx = proxyFactoryInitializable.deployMinimal(logic, data, {"from": deployer})

    wrapperProxy = ERC721ReadOnlyProxyInitializable.at(
        (tx.events["ProxyCreated"]["proxy"]), owner
    )

    assert wrapperProxy.getWrapped() == t2.address

    assert wrapperProxy.symbol() == proxyPrefix + t2.symbol()
    assert wrapperProxy.name() == proxyPrefix + t2.name()
    assert wrapperProxy.owner() == owner


def test_wrappers_proxy_double_init(
    TestNFT,
    ERC721ReadOnlyProxyInitializable,
    proxyFactoryInitializable,
    deployer,
    accounts,
):

    t1 = TestNFT.deploy({"from": deployer})

    t2 = TestNFT.deploy({"from": deployer})

    owner = accounts[4]

    logic = ERC721ReadOnlyProxyInitializable.deploy(t1, "w", {"from": deployer})

    proxyPrefix = "j"
    data = logic.init.encode_input(t2, proxyPrefix, owner)

    tx = proxyFactoryInitializable.deployMinimal(logic, data, {"from": deployer})

    wrapperProxy = ERC721ReadOnlyProxyInitializable.at(
        (tx.events["ProxyCreated"]["proxy"]), owner
    )

    # try to re-init the logic

    with brownie.reverts("Initializable: contract is already initialized"):
        logic.init(t2, "k", owner)

    # try to re-init the proxy

    with brownie.reverts("Initializable: contract is already initialized"):
        wrapperProxy.init(t1, "l", deployer)

def test_wrapper_1155(testNFT, deployer, ERC721ReadOnlyProxy, accounts):
    testNFT.mint(deployer, 123, {"from": deployer})

    prefix = "z"
    wrapper = ERC721ReadOnlyProxy.deploy(testNFT, prefix, {"from": deployer})

    assert wrapper.getWrapped() == testNFT.address

    assert wrapper.symbol() == prefix + testNFT.symbol()
    assert wrapper.name() == prefix + testNFT.name()
    assert wrapper.tokenURI(123) == testNFT.tokenURI(123)

    minter = accounts[0]
    user = accounts[1]
    wrapper.setMinter(minter)
    assert wrapper.getMinter() == minter

    tokenId = 50
    wrapper.mint(user, tokenId, {"from": minter})
    assert wrapper.ownerOf(tokenId) == user

    with brownie.reverts("Only minter"):
        wrapper.mint(user, tokenId + 1, {"from": user})

    with brownie.reverts("Only minter"):
        wrapper.burn(tokenId, {"from": user})

    wrapper.burn(tokenId, {"from": minter})
    with brownie.reverts("ERC721: owner query for nonexistent token"):
        wrapper.ownerOf(tokenId)


def test_wrappers_proxy_init_1155(
    TestNFT1155,
    ERC1155ReadOnlyProxyInitializable,
    proxyFactoryInitializable,
    deployer,
    accounts,
):

    t1 = TestNFT1155.deploy({"from": deployer})

    t2 = TestNFT1155.deploy({"from": deployer})

    owner = accounts[4]

    logic = ERC1155ReadOnlyProxyInitializable.deploy(t1, {"from": deployer})

    data = logic.init.encode_input(t2, owner)

    tx = proxyFactoryInitializable.deployMinimal(logic, data, {"from": deployer})

    wrapperProxy = ERC1155ReadOnlyProxyInitializable.at(
        (tx.events["ProxyCreated"]["proxy"]), owner
    )

    assert wrapperProxy.getWrapped() == t2.address

    assert wrapperProxy.uri(0) == t2.uri(0)

def test_wrappers_proxy_double_init_1155(
    TestNFT1155,
    ERC1155ReadOnlyProxyInitializable,
    proxyFactoryInitializable,
    deployer,
    accounts,
):

    t1 = TestNFT1155.deploy({"from": deployer})

    t2 = TestNFT1155.deploy({"from": deployer})

    owner = accounts[4]

    logic = ERC1155ReadOnlyProxyInitializable.deploy(t1, {"from": deployer})

    data = logic.init.encode_input(t2, owner)

    tx = proxyFactoryInitializable.deployMinimal(logic, data, {"from": deployer})

    wrapperProxy = ERC1155ReadOnlyProxyInitializable.at(
        (tx.events["ProxyCreated"]["proxy"]), owner
    )

    # try to re-init the logic

    with brownie.reverts("Initializable: contract is already initialized"):
        logic.init(t2, owner)

    # try to re-init the proxy

    with brownie.reverts("Initializable: contract is already initialized"):
        wrapperProxy.init(t1, deployer)