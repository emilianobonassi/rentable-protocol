// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IERC721ReadOnlyProxy} from "./interfaces/IERC721ReadOnlyProxy.sol";
import {RentableTypes} from "./RentableTypes.sol";

contract RentableStorageV1 {
    mapping(address => mapping(uint256 => RentableTypes.RentalConditions))
        internal _rentalConditions;

    mapping(address => mapping(uint256 => uint256)) internal _etas;

    mapping(address => address) internal _wrentables;
    mapping(address => IERC721ReadOnlyProxy) internal _orentables;

    mapping(address => uint8) public paymentTokenAllowlist;

    mapping(address => mapping(bytes4 => bool)) internal proxyAllowList;

    uint8 internal constant NOT_ALLOWED_TOKEN = 0;
    uint8 internal constant ERC20_TOKEN = 1;
    uint8 internal constant ERC1155_TOKEN = 2;

    uint16 public constant BASE_FEE = 10000;
    uint16 public fee;

    address payable public feeCollector;

    mapping(address => address) internal _libraries;
}
