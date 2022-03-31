// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin-upgradable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradable/contracts/token/ERC721/ERC721Upgradeable.sol";
import "./IERC721ReadOnlyProxy.sol";

contract ERC721ReadOnlyProxy is
    IERC721ReadOnlyProxy,
    OwnableUpgradeable,
    ERC721Upgradeable
{
    address internal _wrapped;

    address internal _minter;

    modifier onlyMinter() {
        require(_msgSender() == _minter, "Only minter");
        _;
    }

    function __ERC721ReadOnlyProxy_init(
        address wrapped,
        string memory prefix,
        address owner
    ) internal onlyInitializing {
        __ERC721_init(
            string(abi.encodePacked(prefix, ERC721Upgradeable(wrapped).name())),
            string(
                abi.encodePacked(prefix, ERC721Upgradeable(wrapped).symbol())
            )
        );
        __Context_init_unchained();
        _transferOwnership(owner);

        _wrapped = wrapped;
    }

    function getWrapped() external view virtual override returns (address) {
        return _wrapped;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return IERC721MetadataUpgradeable(_wrapped).tokenURI(tokenId);
    }

    function getMinter() external view virtual override returns (address) {
        return _minter;
    }

    function setMinter(address minter_) external virtual override onlyOwner {
        _minter = minter_;
    }

    function mint(address to, uint256 tokenId)
        external
        virtual
        override
        onlyMinter
    {
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId) external virtual override onlyMinter {
        _burn(tokenId);
    }

    fallback() external {
        assembly {
            let free_ptr := mload(0x40)
            calldatacopy(free_ptr, 0, calldatasize())

            let result := staticcall(
                gas(),
                sload(_wrapped.slot),
                free_ptr,
                calldatasize(),
                0,
                0
            )
            returndatacopy(free_ptr, 0, returndatasize())

            if iszero(result) {
                revert(free_ptr, returndatasize())
            }
            return(free_ptr, returndatasize())
        }
    }
}
