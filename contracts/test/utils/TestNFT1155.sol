// contracts/GameItems.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract TestNFT1155 is ERC1155 {
    constructor(string memory uri) ERC1155(uri) {}

    function mint(
        address to,
        uint256 tokenId,
        uint256 amount
    ) public payable {
        _mint(to, tokenId, amount, "");
    }
}
