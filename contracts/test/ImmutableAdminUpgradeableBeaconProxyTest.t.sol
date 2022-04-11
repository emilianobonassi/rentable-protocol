// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.7;

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";

import {TestHelper} from "./TestHelper.t.sol";

import {TestImplLogicV1} from "./mocks/TestImplLogicV1.sol";
import {TestImplLogicV2} from "./mocks/TestImplLogicV2.sol";
import {ImmutableAdminUpgradeableBeaconProxy} from "../upgradability/ImmutableAdminUpgradeableBeaconProxy.sol";
import {ProxyAdmin, TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract ImmutableAdminUpgradeableBeaconProxyTest is DSTest, TestHelper {
    Vm public constant vm = Vm(HEVM_ADDRESS);

    uint256 initialTestNumber;

    TestImplLogicV1 logicV1;

    ImmutableAdminUpgradeableBeaconProxy proxy;
    UpgradeableBeacon beacon;
    ProxyAdmin proxyAdmin;
    address owner;

    function setUp() public {
        owner = getNewAddress();

        vm.startPrank(owner);

        // Deploy logic
        logicV1 = new TestImplLogicV1();
        logicV1.init(0);

        // Deploy proxy

        // 1. deploy admin
        proxyAdmin = new ProxyAdmin();

        // 2.prepare init data
        initialTestNumber = 4;
        bytes memory _data = abi.encodeWithSelector(
            TestImplLogicV1.init.selector,
            initialTestNumber
        );

        // 3. deploy beacon
        beacon = new UpgradeableBeacon(address(logicV1));

        // 4. deploy proxy
        proxy = new ImmutableAdminUpgradeableBeaconProxy(
            address(beacon),
            address(proxyAdmin),
            _data
        );

        vm.stopPrank();
    }

    function testProxySetup() public {
        // proxy admin is the admin
        assertEq(
            address(
                proxyAdmin.getProxyAdmin(
                    TransparentUpgradeableProxy(payable(address(proxy)))
                )
            ),
            address(proxyAdmin)
        );

        // proxy implementation is the v1
        assertEq(
            proxyAdmin.getProxyImplementation(
                TransparentUpgradeableProxy(payable(address(proxy)))
            ),
            address(logicV1)
        );

        // data proxy different data logic
        assertTrue(
            logicV1.getTestNumber() !=
                TestImplLogicV1(address(proxy)).getTestNumber()
        );
    }

    function testUpgradeProxyViaBeacon() public {
        // deploy new logic
        TestImplLogicV2 logicV2 = new TestImplLogicV2();
        logicV2.init(initialTestNumber);

        // upgrade beacon
        switchUser(owner);
        beacon.upgradeTo(address(logicV2));

        // check is still initialized
        vm.expectRevert(
            bytes("Initializable: contract is already initialized")
        );
        TestImplLogicV2(address(proxy)).init(5);
        // and new logic is in place
        assertEq(
            TestImplLogicV2(address(proxy)).getTestNumber(),
            initialTestNumber * 2
        );
    }

    function testChangeProxyBeacon() public {
        // deploy new logic
        TestImplLogicV2 logicV2 = new TestImplLogicV2();
        logicV2.init(initialTestNumber);

        UpgradeableBeacon newBeacon = new UpgradeableBeacon(address(logicV2));

        // change implementation to the proxy
        // only proxyadmin can
        address anotherUser = getNewAddress();
        switchUser(anotherUser);
        vm.expectRevert(bytes(""));
        proxy.upgradeTo(address(newBeacon));

        // call proxyadmin
        switchUser(owner);
        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(proxy))),
            address(newBeacon)
        );

        // check is still initialized
        vm.expectRevert(
            bytes("Initializable: contract is already initialized")
        );
        TestImplLogicV2(address(proxy)).init(5);
        // and new logic is in place
        assertEq(
            TestImplLogicV2(address(proxy)).getTestNumber(),
            initialTestNumber * 2
        );
    }
}
