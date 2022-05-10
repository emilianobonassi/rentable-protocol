// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.7;

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";

import {TestHelper} from "./TestHelper.t.sol";

import {TestHelper} from "./TestHelper.t.sol";

import {TestNFT} from "./mocks/TestNFT.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {DummyERC1155V2} from "./mocks/DummyERC1155V2.sol";

import {ImmutableAdminUpgradeableBeaconProxy} from "../upgradability/ImmutableAdminUpgradeableBeaconProxy.sol";

import {SimpleWallet} from "../wallet/SimpleWallet.sol";

import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {DummyContract} from "./mocks/DummyContract.sol";

contract SimpleWalletTest is DSTest, TestHelper {
    using Address for address;

    Vm public constant vm = Vm(HEVM_ADDRESS);

    address owner;
    address user;

    ProxyAdmin proxyAdmin;

    SimpleWallet simpleWalletLogic;
    UpgradeableBeacon simpleWalletBeacon;

    WETH weth;
    TestNFT testNFT;
    DummyERC1155V2 dummy1155;

    bytes4 constant ERC1271_IS_VALID_SIGNATURE =
        bytes4(keccak256("isValidSignature(bytes32,bytes)"));

    function setUp() public {
        owner = getNewAddress();
        user = getNewAddress();

        vm.startPrank(owner);

        simpleWalletLogic = new SimpleWallet(owner, user);
        simpleWalletBeacon = new UpgradeableBeacon(address(simpleWalletLogic));

        weth = new WETH();
        testNFT = new TestNFT();
        dummy1155 = new DummyERC1155V2();
    }

    function testTransferOwnership() public {
        // change owner
        // only owner
        assertEq(owner, simpleWalletLogic.owner());

        address newOwner = getNewAddress();

        switchUser(getNewAddress());

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        simpleWalletLogic.transferOwnership(newOwner);

        switchUser(owner);

        simpleWalletLogic.transferOwnership(newOwner);

        assertEq(newOwner, simpleWalletLogic.owner());
    }

    function testSetUser() public {
        // change user
        // only admin
        assertEq(user, simpleWalletLogic.getUser());

        address newUser = getNewAddress();

        switchUser(getNewAddress());

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        simpleWalletLogic.setUser(newUser);

        switchUser(owner);
        simpleWalletLogic.setUser(newUser);

        assertEq(newUser, simpleWalletLogic.getUser());
    }

    function testProxyDoubleInit() public {
        vm.expectRevert(
            bytes("Initializable: contract is already initialized")
        );
        simpleWalletLogic.initialize(getNewAddress(), getNewAddress());

        ProxyAdmin newProxyAdmin = new ProxyAdmin();

        UpgradeableBeacon newBeacon = new UpgradeableBeacon(
            address(simpleWalletLogic)
        );

        address newOwner = getNewAddress();
        address newUser = getNewAddress();

        SimpleWallet newWallet = SimpleWallet(
            payable(
                address(
                    new ImmutableAdminUpgradeableBeaconProxy(
                        address(newBeacon),
                        address(newProxyAdmin),
                        abi.encodeWithSelector(
                            SimpleWallet.initialize.selector,
                            newOwner,
                            newUser
                        )
                    )
                )
            )
        );

        vm.expectRevert(
            bytes("Initializable: contract is already initialized")
        );
        newWallet.initialize(getNewAddress(), getNewAddress());
    }

    function testIsValidSignature() public {
        address newUser = 0x6Fdbcdb16027b86aB0fA5846e53B1B0952B4580C;

        switchUser(owner);
        simpleWalletLogic.setUser(newUser);

        bytes memory message = "Example `personal_sign` message";
        bytes32 msgHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n31", message)
        );

        bytes
            memory signature = hex"6e75985bb24a53c8c612c426a1c5b0994be3dce252f0ba6c804e000a3022d3b0344c2685ba3f5c92730a72359af81e618cd8bb63f81816a262211283af6000581b"; // solhint-disable-line

        assertEq(
            ERC1271_IS_VALID_SIGNATURE,
            simpleWalletLogic.isValidSignature(msgHash, signature)
        );
    }

    function testWrongIsValidSignature() public {
        bytes memory message = "Example `personal_sign` message";
        bytes32 msgHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n31", message)
        );

        bytes
            memory signature = hex"6e75985bb24a53c8c612c426a1c5b0994be3dce252f0ba6c804e000a3022d3b0344c2685ba3f5c92730a72359af81e618cd8bb63f81816a262211283af6000581b"; // solhint-disable-line

        vm.expectRevert(bytes("Invalid signer"));
        simpleWalletLogic.isValidSignature(msgHash, signature);
    }

    function testExecuteTx() public {
        //only owner
        //call
        //delegate call

        address dummy = address(new DummyContract());

        bytes memory expectedData = abi.encodeWithSignature(
            "anyFunct(uint256)",
            uint256(2)
        );

        switchUser(user);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        simpleWalletLogic.execute(dummy, 0, expectedData, false);

        switchUser(owner);
        vm.expectCall(address(dummy), expectedData);
        simpleWalletLogic.execute(dummy, 0, expectedData, false);

        vm.expectCall(address(dummy), expectedData);
        simpleWalletLogic.execute(dummy, 0, expectedData, true);

        uint256 value = 0.1 ether;
        vm.deal(owner, value);
        vm.expectCall(address(dummy), expectedData);
        simpleWalletLogic.execute{value: value}(
            dummy,
            value,
            expectedData,
            false
        );

        assertEq(value, dummy.balance);
    }

    function testReceiveERC721() public {
        address sender = getNewAddress();
        uint256 tokenId = 123;

        testNFT.mint(sender, tokenId);

        switchUser(sender);
        testNFT.safeTransferFrom(sender, address(simpleWalletLogic), tokenId);

        assertEq(testNFT.ownerOf(tokenId), address(simpleWalletLogic));
    }

    function testReceiveERC1155() public {
        address sender = getNewAddress();
        uint256 tokenId = 123;
        uint256 qty = 5;

        dummy1155.mint(sender, tokenId, qty);

        switchUser(sender);
        dummy1155.safeTransferFrom(
            sender,
            address(simpleWalletLogic),
            tokenId,
            qty,
            ""
        );

        assertEq(dummy1155.balanceOf(address(simpleWalletLogic), tokenId), qty);
    }

    function testWithdrawERC721() public {
        address sender = getNewAddress();
        uint256 tokenId = 123;

        testNFT.mint(sender, tokenId);

        switchUser(sender);
        testNFT.safeTransferFrom(sender, address(simpleWalletLogic), tokenId);

        switchUser(user);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        simpleWalletLogic.execute(
            address(testNFT),
            0,
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256)",
                address(simpleWalletLogic),
                owner,
                tokenId
            ),
            false
        );

        switchUser(owner);

        simpleWalletLogic.execute(
            address(testNFT),
            0,
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256)",
                address(simpleWalletLogic),
                owner,
                tokenId
            ),
            false
        );

        assertEq(testNFT.ownerOf(tokenId), owner);
    }

    function testWithdrawERC1155() public {
        address sender = getNewAddress();
        uint256 tokenId = 123;
        uint256 qty = 5;

        dummy1155.mint(sender, tokenId, qty);

        switchUser(sender);
        dummy1155.safeTransferFrom(
            sender,
            address(simpleWalletLogic),
            tokenId,
            qty,
            ""
        );

        switchUser(user);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        simpleWalletLogic.execute(
            address(dummy1155),
            0,
            abi.encodeWithSelector(
                dummy1155.safeTransferFrom.selector,
                address(simpleWalletLogic),
                owner,
                tokenId,
                qty,
                ""
            ),
            false
        );

        switchUser(owner);

        simpleWalletLogic.execute(
            address(dummy1155),
            0,
            abi.encodeWithSelector(
                dummy1155.safeTransferFrom.selector,
                address(simpleWalletLogic),
                owner,
                tokenId,
                qty,
                ""
            ),
            false
        );

        assertEq(dummy1155.balanceOf(owner, tokenId), qty);
    }

    function testWithdrawERC20() public {
        address sender = getNewAddress();
        uint256 value = 0.1 ether;

        vm.deal(sender, value);
        switchUser(sender);
        weth.deposit{value: value}();
        assertEq(weth.balanceOf(sender), value);

        weth.transfer(address(simpleWalletLogic), value);

        switchUser(user);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        simpleWalletLogic.execute(
            address(weth),
            0,
            abi.encodeWithSelector(weth.transfer.selector, owner, value),
            false
        );

        switchUser(owner);

        simpleWalletLogic.execute(
            address(weth),
            0,
            abi.encodeWithSelector(weth.transfer.selector, owner, value),
            false
        );

        assertEq(weth.balanceOf(owner), value);
    }

    function testWithdrawETH() public {
        address sender = payable(getNewAddress());
        uint256 value = 0.1 ether;

        vm.deal(sender, value);
        switchUser(sender);
        Address.sendValue(payable(address(simpleWalletLogic)), value);

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        simpleWalletLogic.withdrawETH(value);

        uint256 prebalance = owner.balance;

        switchUser(owner);
        simpleWalletLogic.withdrawETH(value);

        uint256 postBalance = owner.balance;

        assertEq(postBalance - prebalance, value);
    }
}
