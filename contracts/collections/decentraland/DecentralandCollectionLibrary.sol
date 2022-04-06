// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

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
    ) public {
        // Depositor can continue to manage land operators after deposit
        ILandRegistry(tokenAddress).setUpdateOperator(tokenId, user);
    }

    /// @inheritdoc ICollectionLibrary
    function postList(
        address,
        uint256,
        address,
        uint256,
        uint256
    ) public {}

    /// @inheritdoc ICollectionLibrary
    function postRent(
        address tokenAddress,
        uint256 tokenId,
        uint256,
        address,
        address to
    ) public payable {
        // Set renter as land operator
        ILandRegistry(tokenAddress).setUpdateOperator(tokenId, to);
    }

    /// @inheritdoc ICollectionLibrary
    function postExpireRental(
        address tokenAddress,
        uint256 tokenId,
        address from
    ) external payable {
        // Restore current otoken owner as land operator
        ILandRegistry(tokenAddress).setUpdateOperator(tokenId, from);
    }

    /// @inheritdoc ICollectionLibrary
    function postWTokenTransfer(
        address tokenAddress,
        uint256 tokenId,
        address,
        address to
    ) external {
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
    ) external {
        // Depositor can transfer the right to update a land when not rented out
        if (!rented) ILandRegistry(tokenAddress).setUpdateOperator(tokenId, to);
    }
}
