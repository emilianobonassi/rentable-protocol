// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {OTestNFT} from "./utils/OTestNFT.sol";
import {TestNFT} from "./utils/TestNFT.sol";

import {SharedSetup, CheatCodes} from "./SharedSetup.t.sol";

import {IRentable} from "../IRentable.sol";

import {WRentable} from "../WRentable.sol";

contract RentableProxyCall is SharedSetup {
    OTestNFT oTestNFT;

    function setUp() public override {
        super.setUp();

        cheats.startPrank(governance);
        oTestNFT = new OTestNFT(address(testNFT));
        oTestNFT.setRentable(address(rentable));
        cheats.stopPrank();
    }

    function testProxyCall() public {
        address user1 = cheats.addr(1);

        cheats.startPrank(user1);

        cheats.expectRevert(bytes("Only w/o tokens are authorized"));

        rentable.proxyCall(
            address(testNFT),
            0,
            testNFT.balanceOf.selector,
            abi.encode(user1)
        );

        cheats.expectRevert(bytes("Only w/o tokens are authorized"));
        oTestNFT.proxiedBalanceOf(user1);
        cheats.stopPrank();

        cheats.startPrank(governance);
        rentable.setORentable(address(testNFT), address(oTestNFT));
        cheats.stopPrank();

        cheats.startPrank(user1);
        cheats.expectRevert(bytes("Proxy call unauthorized"));
        oTestNFT.proxiedBalanceOf(user1);
        cheats.stopPrank();

        cheats.startPrank(governance);
        rentable.enableProxyCall(
            address(oTestNFT),
            testNFT.balanceOf.selector,
            true
        );
        cheats.stopPrank();

        cheats.startPrank(user1);
        oTestNFT.proxiedBalanceOf(user1);
        cheats.stopPrank();

        cheats.startPrank(governance);
        rentable.setORentable(address(testNFT), address(0));
        cheats.stopPrank();

        cheats.startPrank(user1);
        cheats.expectRevert(bytes("Only w/o tokens are authorized"));
        oTestNFT.proxiedBalanceOf(user1);
        cheats.stopPrank();

        cheats.startPrank(governance);
        rentable.setWRentable(address(testNFT), address(oTestNFT));
        cheats.stopPrank();

        cheats.startPrank(user1);
        oTestNFT.proxiedBalanceOf(user1);
        cheats.stopPrank();
    }
}
