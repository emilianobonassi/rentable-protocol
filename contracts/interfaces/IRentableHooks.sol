// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

/// @title Rentable Shared Hooks
/// @author Rentable Team <hello@rentable.world>
interface IRentableHooks {
    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @dev Implementer will execute the call on the wrapped token
    /// @param to wrapped token address
    /// @param value (optional) ether vaule
    /// @param selector function selector on the target
    /// @param data function data
    function proxyCall(
        address to,
        uint256 value,
        bytes4 selector,
        bytes memory data
    ) external payable returns (bytes memory);
}