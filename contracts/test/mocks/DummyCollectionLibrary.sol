// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {ICollectionLibrary} from "../../collections/ICollectionLibrary.sol";

contract DummyCollectionLibrary is ICollectionLibrary {
    function postDeposit(
        address tokenAddress,
        uint256 tokenId,
        address user
    ) external {}

    function postList(
        address tokenAddress,
        uint256 tokenId,
        address user,
        uint256 maxTimeDuration,
        uint256 pricePerSecond
    ) external {}

    function postCreateRent(
        address tokenAddress,
        uint256 tokenId,
        uint256 duration,
        address from,
        address to
    ) external payable {}

    function postexpireRental(
        address tokenAddress,
        uint256 tokenId,
        address from,
        address to
    ) external payable {}

    function postWTokenTransfer(
        address tokenAddress,
        uint256 tokenId,
        address from,
        address to
    ) external {}

    function postOTokenTransfer(
        address tokenAddress,
        uint256 tokenId,
        address from,
        address to,
        bool rented
    ) external {}
}
