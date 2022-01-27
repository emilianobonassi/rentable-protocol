// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "./ERC721ReadOnlyProxy.sol";
import "@openzeppelin-upgradable/contracts/token/ERC721/ERC721Upgradeable.sol";

contract ERC721ReadOnlyProxyInitializable is ERC721ReadOnlyProxy {
    constructor(address wrapped, string memory prefix)
        ERC721ReadOnlyProxy(wrapped, prefix)
    {}

    function init(
        address wrapped,
        string memory prefix,
        address owner
    ) external virtual {
        _init(wrapped, prefix, owner);
    }
}
