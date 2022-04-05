// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface ICollectionLibrary {
    function postDeposit(
        address tokenAddress,
        uint256 tokenId,
        address user
    ) external;

    function postList(
        address tokenAddress,
        uint256 tokenId,
        address user,
        uint256 maxTimeDuration,
        uint256 pricePerSecond
    ) external;

    function postRent(
        address tokenAddress,
        uint256 tokenId,
        uint256 duration,
        address from,
        address to
    ) external payable;

    function postExpireRental(
        address tokenAddress,
        uint256 tokenId,
        address from,
        address to
    ) external payable;

    function postWTokenTransfer(
        address tokenAddress,
        uint256 tokenId,
        address from,
        address to
    ) external;

    function postOTokenTransfer(
        address tokenAddress,
        uint256 tokenId,
        address from,
        address to,
        bool rented
    ) external;
}
