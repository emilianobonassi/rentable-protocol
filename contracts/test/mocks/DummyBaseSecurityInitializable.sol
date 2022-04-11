// SPDX-License-Identifier: MIT

pragma solidity >=0.8.7;

import {BaseSecurityInitializable} from "../../security/BaseSecurityInitializable.sol";

import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract DummyBaseSecurityInitializable is
    BaseSecurityInitializable,
    ERC1155Holder
{
    constructor(address governance, address operator) {
        _init(governance, operator);
    }

    function _init(address governance, address operator) internal initializer {
        __BaseSecurityInitializable_init(governance, operator);
    }

    receive() external payable {}
}
