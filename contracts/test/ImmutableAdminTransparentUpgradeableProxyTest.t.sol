// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.7;

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";

import {TestHelper} from "./TestHelper.t.sol";

import {TestImplLogicV1} from "./mocks/TestImplLogicV1.sol";
import {TestImplLogicV2} from "./mocks/TestImplLogicV2.sol";
import {ImmutableAdminTransparentUpgradeableProxy} from "../upgradability/ImmutableAdminTransparentUpgradeableProxy.sol";
import {ProxyAdmin, TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract ImmutableAdminTransparentUpgradeableProxyTest is DSTest, TestHelper {
    Vm public constant vm = Vm(HEVM_ADDRESS);

    uint256 initialTestNumber;

    TestImplLogicV1 logicV1;

    ImmutableAdminTransparentUpgradeableProxy proxy;
    ProxyAdmin proxyAdmin;
    address owner;

    function setUp() public {
        owner = vm.addr(1);

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

        // 3. deploy proxy
        proxy = new ImmutableAdminTransparentUpgradeableProxy(
            address(logicV1),
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

        // only owner can transfer ownership
        address anotherUser = vm.addr(2);
        switchUser(anotherUser);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        proxyAdmin.transferOwnership(anotherUser);

        switchUser(owner);
        proxyAdmin.transferOwnership(anotherUser);
        assertEq(proxyAdmin.owner(), anotherUser);

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

    function testUpgradeProxy() public {
        // deploy new logic
        TestImplLogicV2 logicV2 = new TestImplLogicV2();
        logicV2.init(initialTestNumber);

        // change implementation to the proxy
        // only proxyadmin can
        address anotherUser = vm.addr(2);
        switchUser(anotherUser);
        vm.expectRevert(bytes(""));
        proxy.upgradeTo(address(logicV2));

        // upgrade as proxyadmin
        switchUser(owner);
        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(proxy))),
            address(logicV2)
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
