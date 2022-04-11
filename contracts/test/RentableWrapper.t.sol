// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.7;

import {DSTest} from "ds-test/test.sol";

import {TestNFT} from "./mocks/TestNFT.sol";

import {Vm} from "forge-std/Vm.sol";

import {TestHelper} from "./TestHelper.t.sol";

import {ERC721ReadOnlyProxy} from "../tokenization/ERC721ReadOnlyProxy.sol";
import {ERC721ReadOnlyProxyInitializable} from "./mocks/ERC721ReadOnlyProxyInitializable.sol";

import {ImmutableAdminUpgradeableBeaconProxy} from "../upgradability/ImmutableAdminUpgradeableBeaconProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract RentableWrapper is DSTest, TestHelper {
    using Address for address;

    Vm public constant vm = Vm(HEVM_ADDRESS);

    TestNFT testNFT;

    address deployer;

    ERC721ReadOnlyProxyInitializable wrapperLogic;
    string prefix;

    function setUp() public virtual {
        deployer = getNewAddress();

        vm.startPrank(deployer);

        testNFT = new TestNFT();

        prefix = "z";

        wrapperLogic = new ERC721ReadOnlyProxyInitializable(
            address(testNFT),
            prefix
        );

        vm.stopPrank();
    }

    function testWrapperWrapped() public virtual executeByUser(deployer) {
        assertEq(wrapperLogic.getWrapped(), address(testNFT));
    }

    function testWrapperSymbolAndName() public virtual executeByUser(deployer) {
        assertEq(
            wrapperLogic.symbol(),
            string(abi.encodePacked(prefix, testNFT.symbol()))
        );
        assertEq(
            wrapperLogic.name(),
            string(abi.encodePacked(prefix, testNFT.name()))
        );
    }

    function testWrapperTokenURI() public virtual executeByUser(deployer) {
        testNFT.mint(deployer, 123);

        assertEq(wrapperLogic.tokenURI(123), testNFT.tokenURI(123));
    }

    function testWrapperSetMinter() public {
        address minter = getNewAddress();

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        wrapperLogic.setMinter(minter);

        switchUser(deployer);
        wrapperLogic.setMinter(minter);

        assertEq(wrapperLogic.getMinter(), minter);
    }

    function testWrapperMint() public executeByUser(deployer) {
        address minter = getNewAddress();
        address user = getNewAddress();

        wrapperLogic.setMinter(minter);

        uint256 tokenId = 123;
        switchUser(minter);
        wrapperLogic.mint(user, tokenId);

        assertEq(wrapperLogic.ownerOf(tokenId), user);

        address wrongMinter = getNewAddress();
        switchUser(wrongMinter);
        vm.expectRevert(bytes("Only minter"));
        wrapperLogic.mint(user, tokenId + 1);
    }

    function testWrapperBurn() public executeByUser(deployer) {
        address minter = getNewAddress();
        address user = getNewAddress();

        wrapperLogic.setMinter(minter);

        uint256 tokenId = 123;
        switchUser(minter);
        wrapperLogic.mint(user, tokenId);

        address wrongMinter = getNewAddress();
        switchUser(wrongMinter);
        vm.expectRevert(bytes("Only minter"));
        wrapperLogic.burn(tokenId);

        switchUser(minter);
        wrapperLogic.burn(tokenId);
        vm.expectRevert(bytes("ERC721: owner query for nonexistent token"));
        wrapperLogic.ownerOf(tokenId);
    }

    function testProxyCallView() public {
        string memory callResult = abi.decode(
            Address.functionCallWithValue(
                address(wrapperLogic),
                abi.encodeWithSelector(testNFT.simpleView.selector),
                0,
                ""
            ),
            (string)
        );
        assertEq(callResult, testNFT.simpleView());
    }

    function testProxyCallCannotMutate() public {
        vm.expectRevert();
        Address.functionCallWithValue(
            address(wrapperLogic),
            abi.encodeWithSelector(testNFT.simpleMutate.selector),
            0,
            ""
        );
    }

    function testWrapperProxyInit() public {
        TestNFT t1 = new TestNFT();
        TestNFT t2 = new TestNFT();

        address owner = getNewAddress();

        ERC721ReadOnlyProxyInitializable wrapper = new ERC721ReadOnlyProxyInitializable(
                address(t1),
                "w"
            );

        string memory proxyPrefix = "j";

        ProxyAdmin proxyAdmin = new ProxyAdmin();

        UpgradeableBeacon beacon = new UpgradeableBeacon(address(wrapper));

        ERC721ReadOnlyProxy proxyInstance = ERC721ReadOnlyProxy(
            address(
                new ImmutableAdminUpgradeableBeaconProxy(
                    address(beacon),
                    address(proxyAdmin),
                    abi.encodeWithSelector(
                        ERC721ReadOnlyProxyInitializable.initialize.selector,
                        address(t2),
                        proxyPrefix,
                        owner
                    )
                )
            )
        );

        assertEq(
            proxyInstance.symbol(),
            string(abi.encodePacked(proxyPrefix, t2.symbol()))
        );
        assertEq(
            proxyInstance.name(),
            string(abi.encodePacked(proxyPrefix, t2.name()))
        );
        assertEq(proxyInstance.owner(), owner);
    }

    function testWrapperProxyDoubleInit() public {
        TestNFT t1 = new TestNFT();
        TestNFT t2 = new TestNFT();

        address owner = getNewAddress();

        ERC721ReadOnlyProxyInitializable wrapper = new ERC721ReadOnlyProxyInitializable(
                address(t1),
                "w"
            );

        string memory proxyPrefix = "j";

        ProxyAdmin proxyAdmin = new ProxyAdmin();

        UpgradeableBeacon beacon = new UpgradeableBeacon(address(wrapper));

        wrapper = ERC721ReadOnlyProxyInitializable(
            address(
                new ImmutableAdminUpgradeableBeaconProxy(
                    address(beacon),
                    address(proxyAdmin),
                    abi.encodeWithSelector(
                        ERC721ReadOnlyProxyInitializable.initialize.selector,
                        address(t2),
                        proxyPrefix,
                        owner
                    )
                )
            )
        );

        vm.expectRevert(
            bytes("Initializable: contract is already initialized")
        );
        wrapper.initialize(address(t2), "k", owner);

        vm.expectRevert(
            bytes("Initializable: contract is already initialized")
        );
        wrapper.initialize(address(t1), "l", deployer);
    }
}
