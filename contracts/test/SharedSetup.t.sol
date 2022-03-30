// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";

import {TestNFT} from "./utils/TestNFT.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {DummyERC1155} from "./utils/DummyERC1155.sol";

import {ICollectionLibrary} from "../collectionlibs/ICollectionLibrary.sol";
import {IRentable} from "../IRentable.sol";
import {Rentable} from "../Rentable.sol";
import {ORentable} from "../ORentable.sol";
import {WRentable} from "../WRentable.sol";

import {EmergencyImplementation} from "../EmergencyImplementation.sol";

import {DummyCollectionLibrary} from "./utils/DummyCollectionLibrary.sol";

import {RentableTypes} from "./../RentableTypes.sol";
import {IRentableEvents} from "./../IRentableEvents.sol";

interface CheatCodes {
    function prank(address) external;

    function addr(uint256) external returns (address);

    function startPrank(address) external;

    function stopPrank() external;

    function expectEmit(
        bool checkTopic1,
        bool checkTopic2,
        bool checkTopic3,
        bool checkData
    ) external;

    function expectCall(address where, bytes calldata data) external;

    function expectRevert(bytes calldata) external;

    function warp(uint256) external;

    function deal(address who, uint256 newBalance) external;
}

abstract contract SharedSetup is DSTest, IRentableEvents {
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    address user;

    address governance;
    address operator;
    address payable feeCollector;

    WETH weth;

    EmergencyImplementation emergencyImplementation;
    DummyCollectionLibrary dummyLib;

    TestNFT testNFT;
    DummyERC1155 dummy1155;

    Rentable rentable;
    ORentable orentable;
    WRentable wrentable;

    function setUp() public virtual {
        governance = cheats.addr(1);
        operator = cheats.addr(2);
        feeCollector = payable(cheats.addr(3));
        user = cheats.addr(4);

        cheats.startPrank(governance);

        dummyLib = new DummyCollectionLibrary();

        weth = new WETH();

        testNFT = new TestNFT();
        emergencyImplementation = new EmergencyImplementation();

        dummy1155 = new DummyERC1155();

        rentable = new Rentable(governance, operator);

        orentable = new ORentable(address(testNFT));
        orentable.setRentable(address(rentable));
        rentable.setORentable(address(testNFT), address(orentable));

        wrentable = new WRentable(address(testNFT));
        wrentable.setRentable(address(rentable));
        rentable.setWRentable(address(testNFT), address(wrentable));

        rentable.enablePaymentToken(address(0));
        rentable.enablePaymentToken(address(weth));
        rentable.enablePaymentToken(address(dummy1155));

        rentable.setFeeCollector(feeCollector);

        rentable.setLibrary(address(testNFT), address(dummyLib));

        cheats.stopPrank();
    }

    function prepareTestDeposit(uint256 tokenId) internal {
        testNFT.mint(user, tokenId);
        testNFT.approve(address(rentable), tokenId);
    }

    function depositAndApprove(
        address _user,
        uint256 value,
        address paymentToken,
        uint256 paymentTokenId
    ) public {
        cheats.deal(_user, value);
        if (paymentToken == address(weth)) {
            weth.deposit{value: value}();
            weth.approve(address(rentable), ~uint256(0));
        } else if (paymentToken == address(dummy1155)) {
            dummy1155.deposit{value: value}(paymentTokenId);
            dummy1155.setApprovalForAll(address(rentable), true);
        }
    }
}
