// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin-upgradable/contracts/token/ERC721/IERC721Upgradeable.sol";

interface IERC721ReadOnlyProxy is IERC721Upgradeable {
    function getWrapped() external view returns (address);

    function getMinter() external view returns (address);

    function setMinter(address minter_) external;

    function mint(address to, uint256 tokenId) external;

    function burn(uint256 tokenId) external;
}
