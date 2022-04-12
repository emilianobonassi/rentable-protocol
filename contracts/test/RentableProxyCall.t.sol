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

    function testOTokenOrWToken() public executeByUser(user) {
        vm.expectRevert(bytes("Only w/o tokens are authorized"));
        address operator = getNewAddress();
        rentable.proxyCall(
            address(testNFT),
            0,
            testNFT.balanceOf.selector,
            abi.encode(user)
        );

        vm.expectRevert(bytes("Only w/o tokens are authorized"));
        oTestNFT.proxiedSetApprovalForAll(operator, true);

        switchUser(governance);
        // set as oToken
        rentable.setORentable(address(testNFT), address(oTestNFT));

        // should not revert for not being w/o tokens
        vm.expectRevert(bytes("Proxy call unauthorized"));
        oTestNFT.proxiedSetApprovalForAll(operator, true);

        switchUser(governance);
        // set as wToken
        rentable.setWRentable(address(testNFT), address(oTestNFT));

        // should not revert for not being w/o tokens
        vm.expectRevert(bytes("Proxy call unauthorized"));
        oTestNFT.proxiedSetApprovalForAll(operator, true);
    }

    function testOnlyAllowedSelectors() public executeByUser(governance) {
        rentable.setORentable(address(testNFT), address(oTestNFT));
        vm.expectRevert(bytes("Proxy call unauthorized"));
        oTestNFT.proxiedSetApprovalForAll(operator, true);

        rentable.enableProxyCall(
            address(oTestNFT),
            testNFT.setApprovalForAll.selector,
            true
        );

        oTestNFT.proxiedSetApprovalForAll(operator, true);
    }

    function testProxyCallWithData() public executeByUser(governance) {
        rentable.setORentable(address(testNFT), address(oTestNFT));
        rentable.enableProxyCall(
            address(oTestNFT),
            testNFT.setApprovalForAll.selector,
            true
        );
        oTestNFT.proxiedSetApprovalForAll(user, true);
        assertTrue(testNFT.isApprovedForAll(address(rentable), user));
        oTestNFT.proxiedSetApprovalForAll(user, false);
        assertTrue(!testNFT.isApprovedForAll(address(rentable), user));
    }

    function testProxyCallWithNoData() public executeByUser(governance) {
        rentable.setORentable(address(testNFT), address(oTestNFT));
        rentable.enableProxyCall(
            address(oTestNFT),
            testNFT.name.selector,
            true
        );

        assertEq(oTestNFT.proxiedName(), testNFT.name());
    }

    function testProxyCallWithValue() public executeByUser(governance) {
        rentable.setORentable(address(testNFT), address(oTestNFT));
        rentable.enableProxyCall(
            address(oTestNFT),
            testNFT.simplePayable.selector,
            true
        );

        assertEq(address(testNFT).balance, 0);
        uint256 value = 1000;
        vm.deal(governance, value);
        oTestNFT.proxiedSimplePayable{value: value}();
        assertEq(address(testNFT).balance, value);
    }
}
