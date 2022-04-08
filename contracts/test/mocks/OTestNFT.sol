// SPDX-License-Identifier: MIT

pragma solidity >=0.8.7;

import {IORentableHooks} from "../../interfaces/IORentableHooks.sol";

import {ORentable} from "../../tokenization/ORentable.sol";
import {ERC721URIStorageUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";

contract OTestNFT is ORentable {
    constructor(
        address wrapped_,
        address owner,
        address rentable
    ) ORentable(wrapped_, owner, rentable) {}

    function proxiedBalanceOf(address owner) external {
        IORentableHooks(getRentable()).proxyCall(
            getWrapped(),
            0,
            ERC721URIStorageUpgradeable(getWrapped()).balanceOf.selector,
            abi.encode(owner)
        );
    }
}
