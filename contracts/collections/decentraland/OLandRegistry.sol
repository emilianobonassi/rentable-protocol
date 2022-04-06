// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

// Inheritance
import {ORentable} from "../../tokenization/ORentable.sol";

// References
import {IRentable} from "../../interfaces/IRentable.sol";
import {IORentableHooks} from "../../interfaces/IORentableHooks.sol";
import {ILandRegistry} from "./ILandRegistry.sol";

/// @title OToken for Decentraland LAND
/// @author Rentable Team <hello@rentable.world>
/// @notice Represents a transferrable tokenized deposit and mimics the wrapped token
contract OLandRegistry is ORentable {
    /* ========== CONSTRUCTOR ========== */

    /// @notice Instantiate a token
    /// @param wrapped wrapped token address
    /// @param owner admin for the contract
    /// @param rentable rentable address
    constructor(
        address wrapped,
        address owner,
        address rentable
    ) ORentable(wrapped, owner, rentable) {}

    /// @notice Update current land operator, who can update content
    /// @param tokenId land identifier
    /// @param operator operator address
    function setUpdateOperator(uint256 tokenId, address operator) external {
        /// Makes operator updatable from the wrapper by depositor
        /// So depositor can still do OTC rent when not rented via Rentable
        require(ownerOf(tokenId) == msg.sender, "User not allowed");

        require(
            IRentable(_rentable).expiresAt(_wrapped, tokenId) <=
                block.timestamp,
            "Operation not allowed during rental"
        );

        IORentableHooks(_rentable).proxyCall(
            _wrapped,
            0,
            ILandRegistry(_wrapped).setUpdateOperator.selector,
            abi.encode(tokenId, operator)
        );
    }
}
