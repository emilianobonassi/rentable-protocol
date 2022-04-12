// SPDX-License-Identifier: MIT

pragma solidity >=0.8.7;

// Inheritance
import {ICollectionLibrary} from "../ICollectionLibrary.sol";

// References
import {ILandRegistry} from "./ILandRegistry.sol";

/// @title Decentraland LAND collection library
/// @author Rentable Team <hello@rentable.world>
/// @notice Implement dedicated logic for LAND rentals
contract DecentralandCollectionLibrary is ICollectionLibrary {
    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @inheritdoc ICollectionLibrary
    function postDeposit(
        address tokenAddress,
        uint256 tokenId,
        address user
    ) external override {
        // Depositor can continue to manage land operators after deposit
        ILandRegistry(tokenAddress).setUpdateOperator(tokenId, user);
    }

    /// @inheritdoc ICollectionLibrary
    function postList(
        address,
        uint256,
        address,
        uint256,
        uint256,
        uint256
    ) external override {}

    /// @inheritdoc ICollectionLibrary
    // slither-disable-next-line locked-ether
    function postRent(
        address tokenAddress,
        uint256 tokenId,
        uint256,
        address,
        address to
    ) external payable override {
        // Set renter as land operator
        ILandRegistry(tokenAddress).setUpdateOperator(tokenId, to);
    }

    /// @inheritdoc ICollectionLibrary
    // slither-disable-next-line locked-ether
    function postExpireRental(
        address tokenAddress,
        uint256 tokenId,
        address from
    ) external payable override {
        // Restore current otoken owner as land operator
        ILandRegistry(tokenAddress).setUpdateOperator(tokenId, from);
    }

    /// @inheritdoc ICollectionLibrary
    function postWTokenTransfer(
        address tokenAddress,
        uint256 tokenId,
        address,
        address to
    ) external override {
        // Enable subletting, renter can transfer the right to update a land
        ILandRegistry(tokenAddress).setUpdateOperator(tokenId, to);
    }

    /// @inheritdoc ICollectionLibrary
    function postOTokenTransfer(
        address tokenAddress,
        uint256 tokenId,
        address,
        address to,
        bool rented
    ) external override {
        // Depositor can transfer the right to update a land when not rented out
        if (!rented) ILandRegistry(tokenAddress).setUpdateOperator(tokenId, to);
    }
}
