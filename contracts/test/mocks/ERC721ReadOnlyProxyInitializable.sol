// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {ERC721Upgradeable} from "@openzeppelin-upgradable/contracts/token/ERC721/ERC721Upgradeable.sol";
import {ERC721ReadOnlyProxy} from "../../tokenization/ERC721ReadOnlyProxy.sol";

contract ERC721ReadOnlyProxyInitializable is ERC721ReadOnlyProxy {
    constructor(address wrapped, string memory prefix) {
        _initialize(wrapped, prefix, msg.sender);
    }

    function initialize(
        address wrapped,
        string memory prefix,
        address owner
    ) external {
        _initialize(wrapped, prefix, owner);
    }

    function _initialize(
        address wrapped,
        string memory prefix,
        address owner
    ) internal initializer {
        __ERC721ReadOnlyProxy_init(wrapped, prefix, owner);
    }
}
