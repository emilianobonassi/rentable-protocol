// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IRentableHooks {
    function proxyCall(
        address to,
        uint256 value,
        bytes4 selector,
        bytes memory data
    ) external payable returns (bytes memory);
}
