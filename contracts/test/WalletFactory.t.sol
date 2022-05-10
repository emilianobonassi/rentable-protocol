// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.7;

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";

import {TestHelper} from "./TestHelper.t.sol";

import {SimpleWallet} from "../wallet/SimpleWallet.sol";
import {WalletFactory} from "../wallet/WalletFactory.sol";

import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {ProxyAdmin, TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract WalletFactoryTest is DSTest, TestHelper {
    Vm public constant vm = Vm(HEVM_ADDRESS);

    address owner;
    address user;

    ProxyAdmin proxyAdmin;

    SimpleWallet simpleWalletLogic;
    UpgradeableBeacon simpleWalletBeacon;
    WalletFactory walletFactory;

    function setUp() public {
        owner = getNewAddress();
        user = getNewAddress();

        vm.startPrank(owner);

        proxyAdmin = new ProxyAdmin();

        simpleWalletLogic = new SimpleWallet(owner, user);
        simpleWalletBeacon = new UpgradeableBeacon(address(simpleWalletLogic));
        walletFactory = new WalletFactory(
            address(simpleWalletBeacon),
            address(proxyAdmin)
        );
    }

    function testTransferOwnership() public {
        // change owner
        // only owner
        assertEq(owner, walletFactory.owner());

        address newOwner = getNewAddress();

        switchUser(getNewAddress());

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        walletFactory.transferOwnership(newOwner);

        switchUser(owner);

        walletFactory.transferOwnership(newOwner);

        assertEq(newOwner, walletFactory.owner());
    }

    function testSetBeacon() public {
        // change beacon
        // only admin
        assertEq(address(simpleWalletBeacon), walletFactory.getBeacon());

        address newBeacon = getNewAddress();

        switchUser(getNewAddress());

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        walletFactory.setBeacon(newBeacon);

        switchUser(owner);
        walletFactory.setBeacon(newBeacon);

        assertEq(newBeacon, walletFactory.getBeacon());
    }

    function testSetAdmin() public {
        // change admin
        // only admin

        // change beacon
        // only admin
        assertEq(address(proxyAdmin), walletFactory.getAdmin());

        address newProxyAdmin = getNewAddress();

        switchUser(getNewAddress());

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        walletFactory.setAdmin(newProxyAdmin);

        switchUser(owner);
        walletFactory.setAdmin(newProxyAdmin);

        assertEq(newProxyAdmin, walletFactory.getAdmin());
    }

    function testCreateWallet() public {
        // test proxy props and simplewallet ones

        address walletOwner = getNewAddress();
        address walletUser = getNewAddress();

        address payable newWallet = payable(
            walletFactory.createWallet(walletOwner, walletUser)
        );

        // beacon
        assertEq(
            address(simpleWalletLogic),
            proxyAdmin.getProxyImplementation(
                TransparentUpgradeableProxy(newWallet)
            )
        );

        // admin
        assertEq(
            address(proxyAdmin),
            proxyAdmin.getProxyAdmin(TransparentUpgradeableProxy(newWallet))
        );

        // owner
        assertEq(walletOwner, SimpleWallet(newWallet).owner());

        // user
        assertEq(walletUser, SimpleWallet(newWallet).getUser());

        assertTrue(true);
    }
}
