// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IRentable {
    struct RentalConditions {
        uint256 maxTimeDuration;
        uint256 pricePerSecond;
        uint256 paymentTokenId;
        address paymentTokenAddress;
        address privateRenter;
    }

    function expiresAt(address tokenAddress, uint256 tokenId)
        external
        view
        returns (uint256);
}
