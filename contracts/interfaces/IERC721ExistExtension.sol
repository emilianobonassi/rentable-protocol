// SPDX-License-Identifier: MIT

pragma solidity >=0.8.7;

/// @title ERC721 extension with exist function public
/// @author Rentable Team <hello@rentable.world>
interface IERC721ExistExtension {
    /* ========== VIEWS ========== */
    /// @notice Verify a specific token id exist
    /// @param tokenId token id
    /// @return true for existing token, false otw
    function exists(uint256 tokenId) external view returns (bool);
}
