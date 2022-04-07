// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

// Inheritance
import {IERC721ReadOnlyProxy} from "../interfaces/IERC721ReadOnlyProxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

// References
import {IERC721MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

/// @title ERC721 Proxy
/// @author Rentable Team <hello@rentable.world>
/// @notice Simple mintable/burnable read-only proxy
contract ERC721ReadOnlyProxy is
    IERC721ReadOnlyProxy,
    OwnableUpgradeable,
    ERC721Upgradeable
{
    /* ========== STATE VARIABLES ========== */

    // wrapped token address
    address internal _wrapped;
    // minter address
    address internal _minter;

    /* ========== MODIFIERS ========== */

    /// @dev Prevent calling a function from anyone except the minter
    modifier onlyMinter() {
        require(_msgSender() == _minter, "Only minter");
        _;
    }

    /* ========== CONSTRUCTOR ========== */

    /* ---------- INITIALIZER ---------- */

    /// @dev Initialize ERC721ReadOnlyProxy (to be used with proxies)
    /// @param wrapped wrapped token address
    /// @param prefix prefix to prepend to the token symbol
    /// @param owner admin for the contract
    function __ERC721ReadOnlyProxy_init(
        address wrapped,
        string memory prefix,
        address owner
    ) internal onlyInitializing {
        __Context_init_unchained();
        _transferOwnership(owner);

        __ERC721_init(
            string(abi.encodePacked(prefix, ERC721Upgradeable(wrapped).name())),
            string(
                abi.encodePacked(prefix, ERC721Upgradeable(wrapped).symbol())
            )
        );

        _wrapped = wrapped;
    }

    /* ========== SETTERS ========== */

    /// @notice Set minter role
    /// @param minter_ wrapped token address
    function setMinter(address minter_) external onlyOwner {
        _minter = minter_;
    }

    /* ========== VIEWS ========== */

    /// @inheritdoc IERC721ReadOnlyProxy
    function getWrapped() external view virtual override returns (address) {
        return _wrapped;
    }

    /// @notice Get minter role address
    /// @return minter role address
    function getMinter() external view returns (address) {
        return _minter;
    }

    /// @inheritdoc IERC721MetadataUpgradeable
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        // return the underlying wrapped token uri
        return IERC721MetadataUpgradeable(_wrapped).tokenURI(tokenId);
    }

    /// @notice Fallback any (static) call to the wrapped token
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

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @inheritdoc IERC721ReadOnlyProxy
    function mint(address to, uint256 tokenId)
        external
        virtual
        override
        onlyMinter
    {
        _mint(to, tokenId);
    }

    /// @inheritdoc IERC721ReadOnlyProxy
    function burn(uint256 tokenId) external virtual override onlyMinter {
        _burn(tokenId);
    }
}
