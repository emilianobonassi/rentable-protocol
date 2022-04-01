// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IWRentableHooks {
    function afterWTokenTransfer(
        address tokenAddress,
        address from,
        address to,
        uint256 tokenId
    ) external;
}
