// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "../ICollectionLibrary.sol";
import "./ILandRegistry.sol";
import "../../IRentable.sol";

contract DecentralandCollectionLibrary is ICollectionLibrary {
    function postSetLibrary(address tokenAddress) external {
        address rentableAddress = address(this);
        IRentable rentable = IRentable(rentableAddress);
        address orentable = rentable.getORentable(tokenAddress);
        ILandRegistry(tokenAddress).setUpdateManager(
            rentableAddress,
            orentable,
            true
        );
    }

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

    function postCreateRent(
        address tokenAddress,
        uint256 tokenId,
        uint256,
        address,
        address to
    ) public payable {
        ILandRegistry(tokenAddress).setUpdateOperator(tokenId, to);
    }

    function postexpireRental(
        address tokenAddress,
        uint256 tokenId,
        address from,
        address
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
