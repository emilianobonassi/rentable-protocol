// SPDX-License-Identifier: MIT

pragma solidity >=0.8.7;

// Inheritance
import {IERC721ReceiverUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import {IRentableEvents} from "./IRentableEvents.sol";

// References
import {RentableTypes} from "../RentableTypes.sol";

/// @title Rentable protocol user interface
/// @author Rentable Team <hello@rentable.world>
interface IRentable is IRentableEvents, IERC721ReceiverUpgradeable {
    /* ========== VIEWS ========== */

    /// @notice Show current rental conditions for a specific wrapped token
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    /// @return rental conditions, see RentableTypes.RentalConditions for fields
    function rentalConditions(address tokenAddress, uint256 tokenId)
        external
        view
        returns (RentableTypes.RentalConditions memory);

    /// @notice Show rental expiration time for a specific wrapped token
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    /// @return expiration timestamp
    function expiresAt(address tokenAddress, uint256 tokenId)
        external
        view
        returns (uint256);

    /// @dev Show rental validity
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    /// @return true if is expired, false otw
    function isExpired(address tokenAddress, uint256 tokenId)
        external
        view
        returns (bool);

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice Entry point for deposits used by wrapped token safeTransferFrom
    /// @param from depositor
    /// @param tokenId wrapped token id
    /// @param data (optional) abi encoded RentableTypes.RentalConditions rental conditions for listing
    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4);

    /// @notice Withdraw and unwrap deposited token
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    function withdraw(address tokenAddress, uint256 tokenId) external;

    /// @notice Manage rental conditions and listing
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    /// @param rc rental conditions see RentableTypes.RentalConditions
    function createOrUpdateRentalConditions(
        address tokenAddress,
        uint256 tokenId,
        RentableTypes.RentalConditions calldata rc
    ) external;

    /// @notice De-list a wrapped token
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    function deleteRentalConditions(address tokenAddress, uint256 tokenId)
        external;

    /// @notice Rent a wrapped token
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    /// @param duration duration in seconds
    function rent(
        address tokenAddress,
        uint256 tokenId,
        uint256 duration
    ) external payable;
}
