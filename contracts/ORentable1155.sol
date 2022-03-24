// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin-upgradable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradable/contracts/token/ERC721/ERC721Upgradeable.sol";

import "./IORentable1155Hooks.sol";

contract ORentable1155 is OwnableUpgradeable, ERC721Upgradeable {
    address internal _wrapped;
    address internal _rentable;
    address internal _minter;

    modifier onlyMinter() {
        require(msg.sender == _minter, "Only minter");
        _;
    }

    constructor(
        address wrapped,
        string memory name,
        string memory symbol
    ) {
        _init(msg.sender, wrapped, name, symbol);
    }

    function _init(
        address owner,
        address wrapped,
        string memory name,
        string memory symbol
    ) internal initializer {
        __ERC721_init(name, symbol);
        __Context_init_unchained();
        _transferOwnership(owner);

        _wrapped = wrapped;
    }

    function setRentable(address rentable_) external onlyOwner {
        _rentable = rentable_;
        _minter = rentable_;
    }

    function getRentable() external view returns (address) {
        return _rentable;
    }

    function getWrapped() external view returns (address) {
        return _wrapped;
    }

    function mint(address to, uint256 tokenId)
        external
        onlyMinter
        returns (uint256)
    {
        _mint(to, tokenId);

        return tokenId;
    }

    function burn(uint256 tokenId) external onlyMinter {
        _burn(tokenId);
    }

    function exists(uint256 tokenId) external view virtual returns (bool) {
        return super._exists(tokenId);
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._transfer(from, to, tokenId);
        IORentable1155Hooks(_rentable).afterOToken1155Transfer(
            _wrapped,
            from,
            to,
            tokenId
        );
    }
}
