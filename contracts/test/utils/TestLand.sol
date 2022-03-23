// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "../../collectionlibs/decentraland/ILandRegistry.sol";

contract TestLand is ERC721, ILandRegistry {
    mapping(uint256 => address) _updateOperator;

    mapping(address => mapping(address => bool)) _updateManager;

    constructor() ERC721("LAND", "LAND") {}

    function updateOperator(uint256 assetId) external view returns (address) {
        return _updateOperator[assetId];
    }

    function updateManager(address owner, address operator)
        external
        view
        virtual
        override
        returns (bool)
    {
        return _updateManager[owner][operator];
    }

    function setUpdateManager(
        address owner,
        address operator,
        bool approved
    ) external {
        _updateManager[owner][operator] = approved;
    }

    function setUpdateOperator(uint256 assetId, address operator) external {
        _updateOperator[assetId] = operator;
    }

    function mint(address to, uint256 assetId) external {
        _mint(to, assetId);
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        _updateOperator[tokenId] = address(0);
        super._transfer(from, to, tokenId);
    }
}
