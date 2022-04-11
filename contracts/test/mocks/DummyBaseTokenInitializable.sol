// SPDX-License-Identifier: MIT

pragma solidity >=0.8.7;

import {BaseTokenInitializable} from "../../tokenization/BaseTokenInitializable.sol";

contract DummyBaseTokenInitializable is BaseTokenInitializable {
    constructor(
        address wrapped,
        address owner,
        address rentable
    ) BaseTokenInitializable(wrapped, owner, rentable) {}

    function _getPrefix() internal pure override returns (string memory) {
        return "d";
    }
}
