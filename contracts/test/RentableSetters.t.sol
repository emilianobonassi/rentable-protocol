// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.7;

import {SharedSetup} from "./SharedSetup.t.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract RentableSetters is SharedSetup {
    using Address for address;

    function testSetLibrary() public {
        address lib = getNewAddress();
        _onlyGovernance(
            rentable.setLibrary.selector,
            abi.encode(address(testNFT), lib)
        );

        assertEq(rentable.getLibrary(address(testNFT)), lib);
    }

    function testEnableAndDisablePaymentToken() public {
        address token = getNewAddress();
        _onlyGovernance(
            rentable.enablePaymentToken.selector,
            abi.encode(token)
        );

        assertEq(rentable.getPaymentTokenAllowlist(token), 1);

        _onlyGovernance(
            rentable.disablePaymentToken.selector,
            abi.encode(token)
        );

        assertEq(rentable.getPaymentTokenAllowlist(token), 0);
    }

    function testEnableAndDisable1155PaymentToken() public {
        address token = getNewAddress();
        _onlyGovernance(
            rentable.enable1155PaymentToken.selector,
            abi.encode(token)
        );

        assertEq(rentable.getPaymentTokenAllowlist(token), 2);

        _onlyGovernance(
            rentable.disablePaymentToken.selector,
            abi.encode(token)
        );

        assertEq(rentable.getPaymentTokenAllowlist(token), 0);
    }

    function testEnableDisableProxyCall() public {
        address token = getNewAddress();
        _onlyGovernance(
            rentable.enableProxyCall.selector,
            abi.encode(token, testNFT.approve.selector, true)
        );

        assertTrue(
            rentable.isEnabledProxyCall(token, testNFT.approve.selector)
        );

        _onlyGovernance(
            rentable.enableProxyCall.selector,
            abi.encode(token, testNFT.approve.selector, false)
        );

        assertTrue(
            !rentable.isEnabledProxyCall(token, testNFT.approve.selector)
        );
    }

    function testSetFeeCollector() public {
        address token = getNewAddress();
        _onlyGovernance(rentable.setFeeCollector.selector, abi.encode(token));
        assertEq(rentable.getFeeCollector(), token);
    }

    function testSetFee() public {
        uint256 fees = 1000;
        _onlyGovernance(rentable.setFee.selector, abi.encode(fees));
        assertEq(rentable.getFee(), fees);
    }

    function testSetORentable() public {
        address token = getNewAddress();
        _onlyGovernance(
            rentable.setORentable.selector,
            abi.encode(testNFT, token)
        );
        assertEq(rentable.getORentable(address(testNFT)), token);
    }

    function testSetWRentable() public {
        address token = getNewAddress();
        _onlyGovernance(
            rentable.setWRentable.selector,
            abi.encode(testNFT, token)
        );
        assertEq(rentable.getWRentable(address(testNFT)), token);
    }

    function _onlyGovernance(bytes4 selector, bytes memory data)
        internal
        executeByUser(governance)
    {
        address(rentable).functionCallWithValue(
            bytes.concat(selector, data),
            0,
            ""
        );

        switchUser(getNewAddress());

        vm.expectRevert(bytes("Only Governance"));
        address(rentable).functionCallWithValue(
            bytes.concat(selector, data),
            0,
            ""
        );
    }
}
