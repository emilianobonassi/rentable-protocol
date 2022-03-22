// contracts/GameItems.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract DummyERC1155 is ERC1155 {
    uint256 public constant TOKEN1 = 0;
    uint256 public constant TOKEN2 = 1;

    constructor() ERC1155("https://game.example/api/item/{id}.json") {
        _mint(msg.sender, TOKEN1, 10, "");
        _mint(msg.sender, TOKEN2, 10, "");
    }

    function deposit(uint256 tokenId) public payable {
        require(tokenId == TOKEN1 || tokenId == TOKEN2, "Wrong tokenId");
        _mint(msg.sender, tokenId, msg.value, "");
    }
}
