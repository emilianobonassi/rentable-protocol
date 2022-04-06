// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

// Inheritance
import {BaseTokenInitializable} from "./BaseTokenInitializable.sol";

// References
import {IERC721Upgradeable} from "@openzeppelin-upgradable/contracts/token/ERC721/IERC721Upgradeable.sol";
import {IRentable} from "../interfaces/IRentable.sol";
import {IWRentableHooks} from "../interfaces/IWRentableHooks.sol";
import {ERC721Upgradeable} from "@openzeppelin-upgradable/contracts/token/ERC721/ERC721Upgradeable.sol";

contract WRentable is BaseTokenInitializable {
    /* ========== CONSTRUCTOR ========== */

    /// @notice Instantiate a token
    /// @param wrapped wrapped token address
    /// @param owner admin for the contract
    /// @param rentable rentable address
    constructor(
        address wrapped,
        address owner,
        address rentable
    ) BaseTokenInitializable(wrapped, owner, rentable) {}

    /* ========== VIEWS ========== */

    /* ---------- Internal ---------- */
    /// @inheritdoc BaseTokenInitializable
    function _getPrefix() internal virtual override returns (string memory) {
        return "w";
    }

    /* ---------- Public ---------- */

    /// @inheritdoc IERC721Upgradeable
    function ownerOf(uint256 tokenId)
        public
        view
        virtual
        override(ERC721Upgradeable, IERC721Upgradeable)
        returns (address)
    {
        // Check rental expiration
        if (
            IRentable(_rentable).expiresAt(_wrapped, tokenId) > block.timestamp
        ) {
            return super.ownerOf(tokenId);
        } else {
            return address(0);
        }
    }

    /// @notice Verify a specific token id exist
    /// @param tokenId token id
    /// @return true for existing token, false otw
    function exists(uint256 tokenId) external view virtual returns (bool) {
        return super._exists(tokenId);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /* ---------- Internal ---------- */

    /// @inheritdoc ERC721Upgradeable
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        // Notify Rentable after successful transfer
        super._transfer(from, to, tokenId);
        IWRentableHooks(_rentable).afterWTokenTransfer(
            _wrapped,
            from,
            to,
            tokenId
        );
    }
}
