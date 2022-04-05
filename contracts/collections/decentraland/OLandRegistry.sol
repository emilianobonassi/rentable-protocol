// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IRentable} from "../../interfaces/IRentable.sol";
import {IORentableHooks} from "../../interfaces/IORentableHooks.sol";
import {ILandRegistry} from "./ILandRegistry.sol";
import {ORentable} from "../../tokenization/ORentable.sol";

contract OLandRegistry is ORentable {
    constructor(
        address wrapped_,
        address owner,
        address rentable
    ) ORentable(wrapped_, owner, rentable) {}

    function setUpdateOperator(uint256 tokenId, address operator) external {
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
