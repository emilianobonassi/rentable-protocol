// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

library RentableTypes {
    struct RentalConditions {
        uint256 maxTimeDuration;
        uint256 pricePerSecond;
        uint256 paymentTokenId;
        address paymentTokenAddress;
        address privateRenter;
    }
}
