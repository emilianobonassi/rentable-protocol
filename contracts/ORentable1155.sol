// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin-upgradable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradable/contracts/token/ERC1155/ERC1155Upgradeable.sol";

contract ORentable1155 is OwnableUpgradeable, ERC1155Upgradeable {
    address internal _rentable;

    address internal _minter;

    modifier onlyMinter() {
        require(_msgSender() == _minter, "Only minter");
        _;
    }

    constructor() {
        _init(_msgSender());
    }

    function _init(address owner) internal initializer {
        __ERC1155_init("");
        __Context_init_unchained();
        _transferOwnership(owner);
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     */
    function uri(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return super.uri(tokenId);
    }

    function getMinter() external view returns (address) {
        return _minter;
    }

    function setMinter(address minter_) external onlyOwner {
        _minter = minter_;
    }

    function setRentable(address rentable_) external onlyOwner {
        _rentable = rentable_;
        _minter = rentable_;
    }

    function getRentable() external view returns (address) {
        return _rentable;
    }

    function mint(
        address to,
        uint256 tokenId,
        uint256 amount
    ) external onlyMinter returns (uint256) {
        _mint(to, tokenId, amount, "");

        return tokenId;
    }

    function burn(
        address from,
        uint256 tokenId,
        uint256 amount
    ) external virtual onlyMinter {
        _burn(from, tokenId, amount);
    }
}
