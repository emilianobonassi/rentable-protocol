// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract TestNFT is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter internal _tokenIds;

    constructor() ERC721("TestNFT", "TNFT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function mint(
        address to,
        uint256 tokenId,
        string memory _tokenURI
    ) external {
        _mint(to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
    }
}
