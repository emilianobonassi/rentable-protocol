// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "./ERC1155ReadOnlyProxy.sol";

contract ERC1155ReadOnlyProxyInitializable is ERC1155ReadOnlyProxy {
    constructor(address wrapped)
        ERC1155ReadOnlyProxy(wrapped)
    {}

    function init(
        address wrapped,
        address owner
    ) external virtual {
        _init(wrapped, owner);
    }
}
