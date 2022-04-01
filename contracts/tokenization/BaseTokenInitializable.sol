// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {OwnableUpgradeable} from "@openzeppelin-upgradable/contracts/access/OwnableUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin-upgradable/contracts/token/ERC721/ERC721Upgradeable.sol";
import {ERC721ReadOnlyProxy} from "./ERC721ReadOnlyProxy.sol";

abstract contract BaseTokenInitializable is ERC721ReadOnlyProxy {
    address internal _rentable;

    modifier onlyRentable() {
        require(_msgSender() == _rentable, "Only rentable");
        _;
    }

    constructor(
        address wrapped,
        address owner,
        address rentable
    ) {
        _initialize(wrapped, owner, rentable);
    }

    function initialize(
        address wrapped,
        address owner,
        address rentable
    ) external virtual {
        _initialize(wrapped, owner, rentable);
    }

    function _initialize(
        address wrapped,
        address owner,
        address rentable
    ) internal initializer {
        __BaseToken_init(wrapped, _getPrefix(), owner, rentable);
    }

    function __BaseToken_init(
        address wrapped,
        string memory prefix,
        address owner,
        address rentable
    ) internal onlyInitializing {
        __ERC721ReadOnlyProxy_init(wrapped, prefix, owner);
        _setRentable(rentable);
    }

    function _setRentable(address rentable_) internal {
        _rentable = rentable_;
        _minter = rentable_;
    }

    function setRentable(address rentable_) external onlyOwner {
        _setRentable(rentable_);
    }

    function getRentable() external view returns (address) {
        return _rentable;
    }

    function _getPrefix() internal virtual returns (string memory);

    // Reserved storage space to allow for layout changes in the future.
    uint256[50] private ______gap;
}
