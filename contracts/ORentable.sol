// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.9;

import "./ERC721ReadOnlyProxy.sol";

contract ORentable is ERC721ReadOnlyProxy {
    constructor(address wrapped_)
        ERC721ReadOnlyProxy(wrapped_ , "o")
    {}
}