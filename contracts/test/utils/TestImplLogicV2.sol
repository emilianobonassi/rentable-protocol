// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin-upgradable/contracts/proxy/utils/Initializable.sol";
import "./TestImplStorage.sol";

contract TestImplLogicV2 is Initializable, TestImplStorage {
    function init(uint256 _testNumber) external initializer {
        testNumber = _testNumber;
    }

    function getTestNumber() external view returns (uint256) {
        return testNumber * 2;
    }
}
