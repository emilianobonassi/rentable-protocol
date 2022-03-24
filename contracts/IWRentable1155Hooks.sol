// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IWRentable1155Hooks {
    function afterWToken1155Transfer(
        address tokenAddress,
        address from,
        address to,
        uint256 wTokenId
    ) external;
}
