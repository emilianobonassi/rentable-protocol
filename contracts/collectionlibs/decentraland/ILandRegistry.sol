// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface ILandRegistry {
    function updateOperator(uint256 assetId)
        external
        view
        returns (address operator);

    function setUpdateOperator(uint256 assetId, address operator) external;
}
