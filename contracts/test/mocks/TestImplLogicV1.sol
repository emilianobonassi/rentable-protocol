// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Initializable} from "@openzeppelin-upgradable/contracts/proxy/utils/Initializable.sol";
import {TestImplStorage} from "./TestImplStorage.sol";

contract TestImplLogicV1 is Initializable, TestImplStorage {
    function init(uint256 _testNumber) external initializer {
        testNumber = _testNumber;
    }

    function getTestNumber() external view returns (uint256) {
        return testNumber;
    }
}
