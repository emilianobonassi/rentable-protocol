// SPDX-License-Identifier: MIT

pragma solidity >=0.8.7;

import {ICollectionLibrary} from "../../collections/ICollectionLibrary.sol";

contract DummyCollectionLibrary is ICollectionLibrary {
    function postDeposit(
        address tokenAddress,
        uint256 tokenId,
        address user
    ) external override {}

    function postList(
        address tokenAddress,
        uint256 tokenId,
        address user,
        uint256 minTimeDuration,
        uint256 maxTimeDuration,
        uint256 pricePerSecond
    ) external override {}

    function postRent(
        address tokenAddress,
        uint256 tokenId,
        uint256 duration,
        address from,
        address to
    ) external payable override {}

    function postExpireRental(
        address tokenAddress,
        uint256 tokenId,
        address from
    ) external payable override {}

    function postWTokenTransfer(
        address tokenAddress,
        uint256 tokenId,
        address from,
        address to
    ) external override {}

    function postOTokenTransfer(
        address tokenAddress,
        uint256 tokenId,
        address from,
        address to,
        bool rented
    ) external override {}
}
