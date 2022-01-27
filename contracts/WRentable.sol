// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "./ERC721ReadOnlyProxy.sol";

import "./Rentable.sol";

contract WRentable is ERC721ReadOnlyProxy {
    address internal _rentable;

    string constant PREFIX = "w";

    modifier onlyRentable() {
        require(_msgSender() == _rentable, "Only rentable");
        _;
    }

    constructor(address wrapped_) ERC721ReadOnlyProxy(wrapped_, PREFIX) {}

    function init(address wrapped, address owner) external virtual {
        _init(wrapped, PREFIX, owner);
    }

    function setRentable(address rentable_) external onlyOwner {
        _rentable = rentable_;
        _minter = rentable_;
    }

    function getRentable() external view returns (address) {
        return _rentable;
    }

    //TODO: balanceOf

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId)
        public
        view
        virtual
        override
        returns (address)
    {
        Rentable.Lease memory lease = Rentable(_rentable).currentLeases(
            _wrapped,
            tokenId
        );

        if (lease.eta > 0 && lease.eta > block.number) {
            return super.ownerOf(tokenId);
        } else {
            return address(0);
        }
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
        Rentable(_rentable).afterWTokenTransfer(_wrapped, from, to, tokenId);
    }
}
