// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface ILandRegistry {
    function updateOperator(uint256 assetId)
        external
        view
        returns (address operator);

    function setUpdateOperator(uint256 assetId, address operator) external;

    function setUpdateManager(
        address owner,
        address operator,
        bool approved
    ) external;

    function updateManager(address owner, address operator)
        external
        view
        returns (bool);
}
