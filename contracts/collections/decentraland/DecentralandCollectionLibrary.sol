// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {ICollectionLibrary} from "../ICollectionLibrary.sol";
import {ILandRegistry} from "./ILandRegistry.sol";

contract DecentralandCollectionLibrary is ICollectionLibrary {
    function postDeposit(
        address tokenAddress,
        uint256 tokenId,
        address user
    ) public {
        ILandRegistry(tokenAddress).setUpdateOperator(tokenId, user);
    }

    function postList(
        address,
        uint256,
        address,
        uint256,
        uint256
    ) public {}

    function postRent(
        address tokenAddress,
        uint256 tokenId,
        uint256,
        address,
        address to
    ) public payable {
        ILandRegistry(tokenAddress).setUpdateOperator(tokenId, to);
    }

    function postExpireRental(
        address tokenAddress,
        uint256 tokenId,
        address from
    ) external payable {
        ILandRegistry(tokenAddress).setUpdateOperator(tokenId, from);
    }

    function postWTokenTransfer(
        address tokenAddress,
        uint256 tokenId,
        address,
        address to
    ) external {
        ILandRegistry(tokenAddress).setUpdateOperator(tokenId, to);
    }

    function postOTokenTransfer(
        address tokenAddress,
        uint256 tokenId,
        address,
        address to,
        bool rented
    ) external {
        if (!rented) ILandRegistry(tokenAddress).setUpdateOperator(tokenId, to);
    }
}
