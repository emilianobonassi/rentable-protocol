// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {ERC721Upgradeable} from "@openzeppelin-upgradable/contracts/token/ERC721/ERC721Upgradeable.sol";
import {IERC721Upgradeable} from "@openzeppelin-upgradable/contracts/token/ERC721/IERC721Upgradeable.sol";
import {IRentable} from "../interfaces/IRentable.sol";
import {IWRentableHooks} from "../interfaces/IWRentableHooks.sol";
import {BaseTokenInitializable} from "./BaseTokenInitializable.sol";

contract WRentable is BaseTokenInitializable {
    constructor(
        address wrapped,
        address owner,
        address rentable
    ) BaseTokenInitializable(wrapped, owner, rentable) {}

    function _getPrefix() internal virtual override returns (string memory) {
        return "w";
    }

    //TODO: balanceOf

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId)
        public
        view
        virtual
        override(ERC721Upgradeable, IERC721Upgradeable)
        returns (address)
    {
        if (
            IRentable(_rentable).expiresAt(_wrapped, tokenId) > block.timestamp
        ) {
            return super.ownerOf(tokenId);
        } else {
            return address(0);
        }
    }

    function exists(uint256 tokenId) external view virtual returns (bool) {
        return super._exists(tokenId);
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._transfer(from, to, tokenId);
        IWRentableHooks(_rentable).afterWTokenTransfer(
            _wrapped,
            from,
            to,
            tokenId
        );
    }
}
