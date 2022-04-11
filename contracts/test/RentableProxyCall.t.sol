// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.7;

import {OTestNFT} from "./mocks/OTestNFT.sol";
import {TestNFT} from "./mocks/TestNFT.sol";

import {SharedSetup} from "./SharedSetup.t.sol";

import {IRentable} from "../interfaces/IRentable.sol";

import {WRentable} from "../tokenization/WRentable.sol";

contract RentableProxyCall is SharedSetup {
    OTestNFT oTestNFT;

    function setUp() public override {
        super.setUp();

        vm.startPrank(governance);
        oTestNFT = new OTestNFT(
            address(testNFT),
            governance,
            address(rentable)
        );
        vm.stopPrank();
    }

    function testProxyCall() public {
        address user1 = vm.addr(1);

        vm.startPrank(user1);

        vm.expectRevert(bytes("Only w/o tokens are authorized"));

        rentable.proxyCall(
            address(testNFT),
            0,
            testNFT.balanceOf.selector,
            abi.encode(user1)
        );

        vm.expectRevert(bytes("Only w/o tokens are authorized"));
        oTestNFT.proxiedBalanceOf(user1);
        vm.stopPrank();

        vm.startPrank(governance);
        rentable.setORentable(address(testNFT), address(oTestNFT));
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(bytes("Proxy call unauthorized"));
        oTestNFT.proxiedBalanceOf(user1);
        vm.stopPrank();

        vm.startPrank(governance);
        rentable.enableProxyCall(
            address(oTestNFT),
            testNFT.balanceOf.selector,
            true
        );
        vm.stopPrank();

        vm.startPrank(user1);
        oTestNFT.proxiedBalanceOf(user1);
        vm.stopPrank();

        vm.startPrank(governance);
        rentable.setORentable(address(testNFT), address(0));
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(bytes("Only w/o tokens are authorized"));
        oTestNFT.proxiedBalanceOf(user1);
        vm.stopPrank();

        vm.startPrank(governance);
        rentable.setWRentable(address(testNFT), address(oTestNFT));
        vm.stopPrank();

        vm.startPrank(user1);
        oTestNFT.proxiedBalanceOf(user1);
        vm.stopPrank();
    }
}
