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

    function testProxyCall() public executeByUser(user) {
        vm.expectRevert(bytes("Only w/o tokens are authorized"));

        rentable.proxyCall(
            address(testNFT),
            0,
            testNFT.balanceOf.selector,
            abi.encode(user)
        );

        vm.expectRevert(bytes("Only w/o tokens are authorized"));
        oTestNFT.proxiedBalanceOf(user);

        switchUser(governance);
        rentable.setORentable(address(testNFT), address(oTestNFT));

        switchUser(user);
        vm.expectRevert(bytes("Proxy call unauthorized"));
        oTestNFT.proxiedBalanceOf(user);

        switchUser(governance);
        rentable.enableProxyCall(
            address(oTestNFT),
            testNFT.balanceOf.selector,
            true
        );

        switchUser(user);
        oTestNFT.proxiedBalanceOf(user);

        switchUser(governance);
        rentable.setORentable(address(testNFT), address(0));

        switchUser(user);
        vm.expectRevert(bytes("Only w/o tokens are authorized"));
        oTestNFT.proxiedBalanceOf(user);

        switchUser(governance);
        rentable.setWRentable(address(testNFT), address(oTestNFT));

        switchUser(user);
        oTestNFT.proxiedBalanceOf(user);
    }
}
