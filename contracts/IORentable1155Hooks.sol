// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IORentable1155Hooks {
    function afterOToken1155Transfer(
        address tokenAddress,
        address from,
        address to,
        uint256 oTokenId
    ) external;
}
