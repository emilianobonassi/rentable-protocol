// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "../../ORentable.sol";
import "../../IRentable.sol";
import "./ILandRegistry.sol";

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

        IRentable(_rentable).proxyCall(
            _wrapped,
            0,
            ILandRegistry(_wrapped).setUpdateOperator.selector,
            abi.encode(tokenId, operator)
        );
    }
}
