// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

// Inheritance
import {BaseTokenInitializable} from "./BaseTokenInitializable.sol";

// References
import {IORentableHooks} from "../interfaces/IORentableHooks.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

/// @title OToken
/// @author Rentable Team <hello@rentable.world>
/// @notice Represents a transferrable tokenized deposit and mimics the wrapped token
contract ORentable is BaseTokenInitializable {
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
        return "o";
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
        IORentableHooks(_rentable).afterOTokenTransfer(
            _wrapped,
            from,
            to,
            tokenId
        );
    }
}
