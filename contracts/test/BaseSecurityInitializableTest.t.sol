// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.7;

import {Vm} from "forge-std/Vm.sol";
import {stdCheats} from "forge-std/stdlib.sol";

import {DSTest} from "ds-test/test.sol";

import {TestNFT} from "./mocks/TestNFT.sol";
import {DummyERC1155V2} from "./mocks/DummyERC1155V2.sol";

import {WETH} from "solmate/tokens/WETH.sol";

import {TestHelper} from "./TestHelper.t.sol";

import {BaseSecurityInitializable} from "../security/BaseSecurityInitializable.sol";

import {DummyBaseSecurityInitializable} from "./mocks/DummyBaseSecurityInitializable.sol";

import {DummyEmergencyHelper} from "./mocks/DummyEmergencyHelper.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

contract BaseSecurityInitializableTest is DSTest, TestHelper, stdCheats {
    using Address for address;

    Vm public constant vm = Vm(HEVM_ADDRESS);

    address governance;
    address operator;

    BaseSecurityInitializable bsi;

    function setUp() public {
        governance = getNewAddress();
        operator = getNewAddress();

        bsi = new DummyBaseSecurityInitializable(governance, operator);
    }

    //TODO: events

    function _onlyByGovernance(bytes memory data)
        internal
        executeByUser(governance)
    {
        address(bsi).functionCallWithValue(data, 0, "");

        switchUser(getNewAddress());

        vm.expectRevert("Only Governance");
        address(bsi).functionCallWithValue(data, 0, "");

        switchUser(operator);

        vm.expectRevert("Only Governance");
        address(bsi).functionCallWithValue(data, 0, "");
    }

    function testChangeOperator() public {
        address newOperator = getNewAddress();

        _onlyByGovernance(
            abi.encodeWithSelector(
                BaseSecurityInitializable.setOperator.selector,
                newOperator
            )
        );

        assertEq(bsi.getOperator(), newOperator);
    }

    function testChangeGovernance() public {
        address newGovernance = getNewAddress();

        _onlyByGovernance(
            abi.encodeWithSelector(
                BaseSecurityInitializable.setGovernance.selector,
                newGovernance
            )
        );

        vm.prank(governance);
        vm.expectRevert(bytes("Only Proposed Governance"));
        bsi.acceptGovernance();

        vm.prank(operator);
        vm.expectRevert(bytes("Only Proposed Governance"));
        bsi.acceptGovernance();

        vm.prank(getNewAddress());
        vm.expectRevert(bytes("Only Proposed Governance"));
        bsi.acceptGovernance();

        vm.startPrank(newGovernance);
        bsi.acceptGovernance();

        assertEq(bsi.getGovernance(), newGovernance);
    }

    function testPauseByGovernance() public executeByUser(governance) {
        bsi.SCRAM();

        assert(bsi.paused());
    }

    function testPauseByOperator() public executeByUser(operator) {
        bsi.SCRAM();

        assert(bsi.paused());
    }

    function testCannotPauseAnotherAddress()
        public
        executeByUser(getNewAddress())
    {
        vm.expectRevert(bytes("Only Operator or Governance"));
        bsi.SCRAM();
    }

    function testUnPauseOnlyGov() public {
        vm.prank(governance);
        bsi.SCRAM();

        _onlyByGovernance(
            abi.encodeWithSelector(BaseSecurityInitializable.unpause.selector)
        );

        assert(!bsi.paused());
    }

    function testEmergencyMethodsNotWhenUnpaused() public {
        uint256[] memory ids = new uint256[](0);

        vm.expectRevert(bytes("Pausable: not paused"));
        bsi.emergencyWithdrawERC20ETH(getNewAddress());

        vm.expectRevert(bytes("Pausable: not paused"));
        bsi.emergencyBatchWithdrawERC721(getNewAddress(), ids, true);

        vm.expectRevert(bytes("Pausable: not paused"));
        bsi.emergencyBatchWithdrawERC1155(getNewAddress(), ids);

        vm.expectRevert(bytes("Pausable: not paused"));
        bsi.emergencyExecute(getNewAddress(), 0, "", true);
    }

    function testEmergencyETHWithdraw() public {
        address depositor = getNewAddress();
        uint256 value = 1 ether;
        hoax(depositor, value);
        Address.sendValue(payable(address(bsi)), value);

        switchUser(governance);
        bsi.SCRAM();

        uint256 govPreBalance = governance.balance;
        bsi.emergencyWithdrawERC20ETH(address(0));

        assertEq(governance.balance - govPreBalance, value);
    }

    function testEmergencyERC20Withdraw() public {
        WETH weth = new WETH();
        address depositor = getNewAddress();
        uint256 value = 1 ether;
        vm.deal(depositor, value);

        switchUser(depositor);
        Address.sendValue(payable(weth), value);
        weth.transfer(address(bsi), value);

        switchUser(governance);
        bsi.SCRAM();

        uint256 govPreBalance = weth.balanceOf(governance);
        bsi.emergencyWithdrawERC20ETH(address(weth));

        assertEq(weth.balanceOf(governance) - govPreBalance, value);
    }

    function testEmergencyERC721Withdraw() public {
        // i = 0, safe
        // i = 1, notSafe
        for (uint256 i = 0; i < 1; i++) {
            TestNFT token = new TestNFT();
            uint256 tokenId;
            token.mint(address(bsi), tokenId);

            switchUser(governance);
            bsi.SCRAM();

            uint256[] memory ids = new uint256[](1);
            ids[0] = tokenId;

            bytes memory expectedData = abi.encodeWithSignature(
                i == 0
                    ? "safeTransferFrom(address,address,uint256)"
                    : "transferFrom(address,address,uint256)",
                address(bsi),
                address(governance),
                tokenId
            );
            vm.expectCall(address(token), expectedData);

            bsi.emergencyBatchWithdrawERC721(address(token), ids, i == 1);

            assertEq(token.ownerOf(tokenId), governance);
        }
    }

    function testEmergencyERC1155Withdraw() public {
        DummyERC1155V2 token = new DummyERC1155V2();
        uint256 tokenId = 1;
        uint256 qty = 1;
        token.mint(address(bsi), tokenId, qty);

        switchUser(governance);
        bsi.SCRAM();

        uint256[] memory ids = new uint256[](1);
        ids[0] = tokenId;

        bsi.emergencyBatchWithdrawERC1155(address(token), ids);

        assertEq(token.balanceOf(governance, tokenId), qty);
    }

    function testEmergencyExecution() public {
        DummyEmergencyHelper helper = new DummyEmergencyHelper();

        switchUser(governance);
        bsi.SCRAM();

        uint256 fieldValue = 3;

        bsi.emergencyExecute(
            address(helper),
            0,
            abi.encodeWithSelector(helper.setField.selector, (fieldValue)),
            false
        );

        assertEq(helper.field(), fieldValue);

        bsi.emergencyExecute(
            address(helper),
            0,
            abi.encodeWithSelector(helper.revertOnDelegate.selector),
            false
        );

        vm.expectRevert(bytes("Called via delegate"));
        bsi.emergencyExecute(
            address(helper),
            0,
            abi.encodeWithSelector(helper.revertOnDelegate.selector),
            true
        );
    }
}
