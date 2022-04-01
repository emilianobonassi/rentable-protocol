// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {BaseTokenInitializable} from "./BaseTokenInitializable.sol";
import "./IORentableHooks.sol";

contract ORentable is BaseTokenInitializable {
    constructor(
        address wrapped,
        address owner,
        address rentable
    ) BaseTokenInitializable(wrapped, owner, rentable) {}

    function _getPrefix() internal virtual override returns (string memory) {
        return "o";
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._transfer(from, to, tokenId);
        IORentableHooks(_rentable).afterOTokenTransfer(
            _wrapped,
            from,
            to,
            tokenId
        );
    }
}
