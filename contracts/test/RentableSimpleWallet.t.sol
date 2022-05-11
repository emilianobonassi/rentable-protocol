// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.7;

import {SharedSetup} from "./SharedSetup.t.sol";

import {SimpleWallet} from "../wallet/SimpleWallet.sol";

import {IWalletFactory} from "../wallet/IWalletFactory.sol";
import {ProxyAdmin, TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract RentableSimpleWallet is SharedSetup {
    function testWalletCorrectProperties() public {
        address aUser = getNewAddress();

        SimpleWallet newWallet = SimpleWallet(
            rentable.createWalletForUser(aUser)
        );

        assertEq(newWallet.getUser(), aUser);

        // owner is rentable
        assertEq(newWallet.owner(), address(rentable));

        // proxy admin is the default proxy admin
        assertEq(
            address(proxyAdmin),
            proxyAdmin.getProxyAdmin(
                TransparentUpgradeableProxy(payable(address(newWallet)))
            )
        );
    }

    function testWalletCannotCreateMultipleTimesSameUser() public {
        address aUser = getNewAddress();

        SimpleWallet(rentable.createWalletForUser(aUser));

        vm.expectRevert(bytes("Wallet already existing"));
        SimpleWallet(rentable.createWalletForUser(aUser));
    }

    function testWalletCannotCreateForAddressZero() public {
        vm.expectRevert(bytes("Cannot create a smart wallet for the void"));
        SimpleWallet(rentable.createWalletForUser(address(0)));
    }

    function testBadFactorySafeCheck() public {
        vm.mockCall(
            address(walletFactory),
            abi.encodeWithSelector(IWalletFactory.createWallet.selector),
            abi.encode(address(0))
        );

        vm.expectRevert(
            bytes("Wallet Factory is not returning a valid wallet address")
        );
        rentable.createWalletForUser(getNewAddress());
    }
}
