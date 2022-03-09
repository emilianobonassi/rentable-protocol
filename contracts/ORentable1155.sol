// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "./ERC1155ReadOnlyProxy.sol";

// interface IORentableHooks {
//     function afterOTokenTransfer(
//         address tokenAddress,
//         address from,
//         address to,
//         uint256 tokenId
//     ) external;
// }

contract ORentable1155 is ERC1155ReadOnlyProxy {
    address internal _rentable;

    constructor(address wrapped_) ERC1155ReadOnlyProxy(wrapped_) {}

    function init(address wrapped, address owner) external virtual {
        _init(wrapped, owner);
    }

    function setRentable(address rentable_) external onlyOwner {
        _rentable = rentable_;
        _minter = rentable_;
    }

    function getRentable() external view returns (address) {
        return _rentable;
    }

    //TODO: notify Rentable 1155 is transferred
/*     function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._transfer(from, to, tokenId);
        IORentableHooks(_rentable).afterOTokenTransfer(
            _wrapped,
            from,
            to,
            tokenId
        );
    } */
}
