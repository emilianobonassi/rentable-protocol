// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

/// @title Rentable wallet factory interface
/// @author Rentable Team <hello@rentable.world>
/// @notice Wallet factory interface
interface IWalletFactory {
    /// @notice Create a new wallet
    /// @param owner address for owner role
    /// @param user address for user role
    function createWallet(address owner, address user)
        external
        returns (address wallet);
}
