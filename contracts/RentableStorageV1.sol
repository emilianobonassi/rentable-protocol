// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

// References
import {IERC721ReadOnlyProxy} from "./interfaces/IERC721ReadOnlyProxy.sol";
import {RentableTypes} from "./RentableTypes.sol";

/// @title Rentable Storage contract
/// @author Rentable Team <hello@rentable.world>
contract RentableStorageV1 {
    /* ========== CONSTANTS ========== */

    // paymentTokenAllowlist possible values
    // used during fee distribution
    uint8 internal constant NOT_ALLOWED_TOKEN = 0;
    uint8 internal constant ERC20_TOKEN = 1;
    uint8 internal constant ERC1155_TOKEN = 2;

    // percentage protocol fee, min 0.01%
    uint16 internal constant BASE_FEE = 10000;

    /* ========== STATE VARIABLES ========== */

    // (token address, token id) => rental conditions mapping
    mapping(address => mapping(uint256 => RentableTypes.RentalConditions))
        internal _rentalConditions;

    // (token address, token id) => rental expiration mapping
    mapping(address => mapping(uint256 => uint256)) internal _expiresAt;

    // token address => o/w token mapping
    mapping(address => IERC721ReadOnlyProxy) internal _wrentables;
    mapping(address => IERC721ReadOnlyProxy) internal _orentables;

    // token address => library mapping, for custom logic execution
    mapping(address => address) internal _libraries;

    // allowed payment tokens, see fee distribution in Rentable-rent
    mapping(address => uint8) internal _paymentTokenAllowlist;

    // enabled selectors for target, see Rentable-proxyCall
    mapping(address => mapping(bytes4 => bool)) internal _proxyAllowList;

    // protocol fee
    uint16 internal _fee;
    // protocol fee collector
    address payable internal _feeCollector;
}
