// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "../../ORentable.sol";
import "../../IRentable.sol";
import "./ILandRegistry.sol";

contract OLandRegistry is ORentable {
    constructor(address wrapped_) ORentable(wrapped_) {}

    function setUpdateOperator(uint256 tokenId, address operator) external {
        require(ownerOf(tokenId) == msg.sender, "User not allowed");

        require(
            IRentable(_rentable).expiresAt(_wrapped, tokenId) <=
                block.timestamp,
            "Operation not allowed during rental"
        );

        ILandRegistry(_wrapped).setUpdateOperator(tokenId, operator);
    }
}
