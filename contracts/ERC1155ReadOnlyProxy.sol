// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin-upgradable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradable/contracts/token/ERC1155/ERC1155Upgradeable.sol";

contract ERC1155ReadOnlyProxy is OwnableUpgradeable, ERC1155Upgradeable {
    address internal _wrapped;

    address internal _minter;

    modifier onlyMinter() {
        require(_msgSender() == _minter, "Only minter");
        _;
    }

    constructor(address wrapped) {
        _init(wrapped, _msgSender());
    }

    function _init(
        address wrapped,
        address owner
    ) internal initializer {
        __ERC1155_init('');
        __Context_init_unchained();
        _transferOwnership(owner);

        _wrapped = wrapped;
    }

    function getWrapped() external view returns (address) {
        return _wrapped;
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     */
    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        return IERC1155MetadataURIUpgradeable(_wrapped).uri(tokenId);
    }

    function getMinter() external view returns (address) {
        return _minter;
    }

    function setMinter(address minter_) external onlyOwner {
        _minter = minter_;
    }

    function mint(address to, uint256 tokenId, uint256 amount)
        external
        onlyMinter
        returns (uint256)
    {
        _mint(to, tokenId, amount, '');

        return tokenId;
    }

    function burn(address from, uint256 tokenId, uint256 amount) external virtual onlyMinter {
        _burn(from, tokenId, amount);
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
