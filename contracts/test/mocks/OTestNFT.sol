// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {IRentable} from "../../interfaces/IRentable.sol";

import {ORentable} from "../../tokenization/ORentable.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract OTestNFT is ORentable {
    constructor(
        address wrapped_,
        address owner,
        address rentable
    ) ORentable(wrapped_, owner, rentable) {}

    function proxiedBalanceOf(address owner) external {
        IRentable(_rentable).proxyCall(
            _wrapped,
            0,
            ERC721URIStorage(_wrapped).balanceOf.selector,
            abi.encode(owner)
        );
    }
}