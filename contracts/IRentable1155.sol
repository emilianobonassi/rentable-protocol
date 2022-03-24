// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IRentable1155 {
    struct RentalConditions {
        uint256 maxTimeDuration;
        uint256 pricePerBlock;
        uint256 paymentTokenId;
        address paymentTokenAddress;
        address privateRenter;
    }

    struct Rental {
        uint256 eta;
        uint256 amount;
    }

    function rentals(address wTokenAddress, uint256 wTokenId)
        external
        view
        returns (Rental memory);
}
