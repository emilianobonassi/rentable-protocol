def test_registry(rentable, orentable, wrentable, testNFT):
    assert rentable.getORentable(testNFT) == orentable.address
    assert rentable.getWRentable(testNFT) == wrentable.address
