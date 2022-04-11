// contracts/GameItems.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract DummyERC1155V2 is ERC1155 {
    constructor() ERC1155("https://game.example/api/item/{id}.json") {}

    function mint(
        address to,
        uint256 tokenId,
        uint256 qty
    ) external {
        _mint(to, tokenId, qty, "");
    }
}
