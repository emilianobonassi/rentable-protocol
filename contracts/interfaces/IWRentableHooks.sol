// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IRentableHooks} from "./IRentableHooks.sol";

interface IWRentableHooks is IRentableHooks {
    function afterWTokenTransfer(
        address tokenAddress,
        address from,
        address to,
        uint256 tokenId
    ) external;
}
