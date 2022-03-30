// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IRentableEvents {
    event Deposit(
        address indexed who,
        address indexed tokenAddress,
        uint256 indexed tokenId
    );
    event UpdateRentalConditions(
        address indexed tokenAddress,
        uint256 indexed tokenId,
        address paymentTokenAddress,
        uint256 paymentTokenId,
        uint256 maxTimeDuration,
        uint256 pricePerSecond,
        address privateRenter
    );
    event Withdraw(address indexed tokenAddress, uint256 indexed tokenId);
    event Rent(
        address from,
        address indexed to,
        address indexed tokenAddress,
        uint256 indexed tokenId,
        address paymentTokenAddress,
        uint256 paymentTokenId,
        uint256 expiresAt
    );
    event RentEnds(address indexed tokenAddress, uint256 indexed tokenId);
}
