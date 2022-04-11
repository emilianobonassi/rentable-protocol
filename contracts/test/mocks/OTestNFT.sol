// SPDX-License-Identifier: MIT

pragma solidity >=0.8.7;

import {IORentableHooks} from "../../interfaces/IORentableHooks.sol";
import {TestNFT} from "./TestNFT.sol";

import {ORentable} from "../../tokenization/ORentable.sol";
import {ERC721URIStorageUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";

contract OTestNFT is ORentable {
    constructor(
        address wrapped_,
        address owner,
        address rentable
    ) ORentable(wrapped_, owner, rentable) {}

    function proxiedSetApprovalForAll(address operator, bool approved)
        external
    {
        IORentableHooks(getRentable()).proxyCall(
            getWrapped(),
            0,
            ERC721URIStorageUpgradeable(getWrapped())
                .setApprovalForAll
                .selector,
            abi.encode(operator, approved)
        );
    }

    function proxiedName() external returns (string memory) {
        return
            abi.decode(
                IORentableHooks(getRentable()).proxyCall(
                    getWrapped(),
                    0,
                    ERC721URIStorageUpgradeable(getWrapped()).name.selector,
                    ""
                ),
                (string)
            );
    }

    function proxiedDonate() external payable {
        IORentableHooks(getRentable()).proxyCall{value: msg.value}(
            getWrapped(),
            msg.value,
            TestNFT(getWrapped()).donate.selector,
            ""
        );
    }
}
