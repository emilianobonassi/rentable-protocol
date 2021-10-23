import brownie

def test_wrapper(testNFT, deployer, ERC721ReadOnlyProxy, accounts):
    testNFT.mint(deployer, 123, {'from': deployer})
    
    prefix = "z"
    wrapper = ERC721ReadOnlyProxy.deploy(
        testNFT, prefix,
        {'from': deployer}
    )

    assert wrapper.getWrapped() == testNFT.address

    assert wrapper.symbol() == prefix + testNFT.symbol()
    assert wrapper.name() == prefix + testNFT.name()
    assert wrapper.tokenURI(123) == testNFT.tokenURI(123)

    minter = accounts[0]
    user = accounts[1]
    wrapper.setMinter(minter)
    assert wrapper.getMinter() == minter

    tokenId = 50
    wrapper.mint(user, tokenId, {'from': minter})
    assert wrapper.ownerOf(tokenId) == user

    with brownie.reverts("Only minter"):
        wrapper.mint(user, tokenId+1, {'from': user})

    with brownie.reverts("Only minter"):
        wrapper.burn(tokenId, {'from': user})

    wrapper.burn(tokenId, {'from': minter})
    with brownie.reverts("ERC721: owner query for nonexistent token"):
        wrapper.ownerOf(tokenId)
