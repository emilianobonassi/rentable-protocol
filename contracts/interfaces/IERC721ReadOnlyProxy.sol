// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

// Inheritance
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

/// @title ERC721 Proxy Interface
/// @author Rentable Team <hello@rentable.world>
/// @notice O/W token interface used by Rentable main contract
interface IERC721ReadOnlyProxy is IERC721Upgradeable {
    /* ========== VIEWS ========== */

    /// @notice Get wrapped token address
    /// @return wrapped token address
    function getWrapped() external view returns (address);

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice Mint a token
    /// @param to receiver
    /// @param tokenId token id
    function mint(address to, uint256 tokenId) external;

    /// @notice Burn a token
    /// @param tokenId token id
    function burn(uint256 tokenId) external;
}
