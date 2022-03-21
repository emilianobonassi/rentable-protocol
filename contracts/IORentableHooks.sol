// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IORentableHooks {
    function afterOTokenTransfer(
        address tokenAddress,
        address from,
        address to,
        uint256 tokenId
    ) external;
}
