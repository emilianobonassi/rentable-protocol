// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract TestNFT is ERC721URIStorage {
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

    function mintBatch(
        address[] memory to,
        uint256[] memory tokenIds,
        string[] memory _tokenURIs
    ) external {
        for (uint256 i = 0; i < to.length; i++) {
            _mint(to[i], tokenIds[i]);
            _setTokenURI(tokenIds[i], _tokenURIs[i]);
        }
    }
}
