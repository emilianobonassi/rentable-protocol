from brownie import (
    accounts,
    TestNFT,
)


def chunks(lst, n):
    """Yield successive n-sized chunks from lst."""
    for i in range(0, len(lst), n):
        yield lst[i : i + n]


def main():
    dev = accounts.load("rentable-deployer")
    testNFT = TestNFT.at("0x8fA4d7B0C204B8f03C9f037E05Cece57decE2214")

    file = open("./fixtures/nfts-to-be-minted.txt")
    uris = file.read().splitlines()
    file.close()

    print(len(uris))
    chunkSize = 120

    cks = chunks(uris, chunkSize)

    i = 1

    for c in cks:
        to = []
        ids = []
        tokenUris = []
        for j in range(len(c)):
            ids.append(i)
            to.append(dev.address)
            tokenUris.append(c[j])
            i += 1
        testNFT.mintBatch(to, ids, tokenUris, {"from": dev})
