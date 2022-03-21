// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IRentable {
    function expiresAt(address tokenAddress, uint256 tokenId)
        external
        view
        returns (uint256);
}
