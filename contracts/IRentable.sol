// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IRentable {
    struct Lease {
        uint256 eta;
    }

    function currentLeases(address tokenAddress, uint256 tokenId)
        external
        view
        returns (Lease memory);
}
