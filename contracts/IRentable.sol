// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface IRentable {
    struct Lease {
        uint256 eta;
        uint256 qtyToPullRemaining;
        uint256 feesToPullRemaining;
        uint256 lastUpdated;
        uint256 tokenId;
        uint256 paymentTokenId;
        address paymentTokenAddress;
        address tokenAddress;
        address from;
        address to;
    }

    function currentLeases(address tokenAddress, uint256 tokenId)
        external
        view
        returns (Lease memory);
}
