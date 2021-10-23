// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract ERC721ReadOnlyProxy is Ownable, ERC721Enumerable {
    address internal _wrapped;

    address internal _minter;

    modifier onlyMinter() {
        require(_msgSender() == _minter, 'Only minter');
        _;
    }

    constructor(address wrapped, string memory prefix) 
        ERC721(string(abi.encodePacked(prefix, ERC721(wrapped).name())), string(abi.encodePacked(prefix, ERC721(wrapped).symbol())))
    {
        _wrapped = wrapped;
    }

    function getWrapped() external view returns (address) {
        return _wrapped;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        return IERC721Metadata(_wrapped).tokenURI(tokenId);
    }

    function getMinter()
        external view returns (address)
    {
        return _minter;
    }

    function setMinter(address minter_)
        external
        onlyOwner
    {
        _minter = minter_;
    }

    function mint(address to, uint256 tokenId)
        external
        onlyMinter
        returns (uint256)
    {
        _mint(to, tokenId);

        return tokenId;
    }

    function burn(uint256 tokenId)
        external
        virtual
        onlyMinter {
        _burn(tokenId);
    }


    fallback () external {
        assembly {
            let free_ptr := mload(0x40)
            calldatacopy(free_ptr, 0, calldatasize())

            let result := staticcall(gas(), sload(_wrapped.slot), free_ptr, calldatasize(), 0, 0)
            returndatacopy(free_ptr, 0, returndatasize())

            if iszero(result) { revert(free_ptr, returndatasize()) }
            return(free_ptr, returndatasize())
        }
    }
}