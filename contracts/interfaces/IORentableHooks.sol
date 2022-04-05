// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IRentableHooks} from "./IRentableHooks.sol";

interface IORentableHooks is IRentableHooks {
    function afterOTokenTransfer(
        address tokenAddress,
        address from,
        address to,
        uint256 tokenId
    ) external;
}
