// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.7;

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";

import {TestHelper} from "./TestHelper.t.sol";

import {TestNFT} from "./mocks/TestNFT.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {DummyERC1155} from "./mocks/DummyERC1155.sol";

import {ICollectionLibrary} from "../collections/ICollectionLibrary.sol";
import {IRentable} from "../interfaces/IRentable.sol";
import {BaseTokenInitializable} from "../tokenization/BaseTokenInitializable.sol";

import {Rentable} from "../Rentable.sol";
import {ORentable} from "../tokenization/ORentable.sol";
import {WRentable} from "../tokenization/WRentable.sol";

import {DummyCollectionLibrary} from "./mocks/DummyCollectionLibrary.sol";

import {RentableTypes} from "./../RentableTypes.sol";
import {IRentableEvents} from "./../interfaces/IRentableEvents.sol";

import {ImmutableAdminTransparentUpgradeableProxy} from "../upgradability/ImmutableAdminTransparentUpgradeableProxy.sol";
import {ImmutableAdminUpgradeableBeaconProxy} from "../upgradability/ImmutableAdminUpgradeableBeaconProxy.sol";

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

abstract contract SharedSetup is DSTest, TestHelper, IRentableEvents {
    Vm public constant vm = Vm(HEVM_ADDRESS);

    address user;

    address governance;
    address operator;
    address payable feeCollector;

    WETH weth;

    DummyCollectionLibrary dummyLib;

    TestNFT testNFT;
    DummyERC1155 dummy1155;

    Rentable rentableLogic;
    ProxyAdmin proxyAdmin;

    Rentable rentable;
    ORentable orentable;
    WRentable wrentable;

    UpgradeableBeacon obeacon;
    ORentable orentableLogic;
    UpgradeableBeacon wbeacon;
    WRentable wrentableLogic;

    address paymentTokenAddress = address(0);
    uint256 paymentTokenId = 0;
    uint256 tokenId = 123;

    function setUp() public virtual {
        user = getNewAddress();
        governance = getNewAddress();
        operator = getNewAddress();
        feeCollector = payable(getNewAddress());

        vm.startPrank(governance);

        dummyLib = new DummyCollectionLibrary();

        weth = new WETH();

        testNFT = new TestNFT();

        dummy1155 = new DummyERC1155();

        rentableLogic = new Rentable(governance, address(0));
        proxyAdmin = new ProxyAdmin();
        rentable = Rentable(
            address(
                new ImmutableAdminTransparentUpgradeableProxy(
                    address(rentableLogic),
                    address(proxyAdmin),
                    abi.encodeWithSelector(
                        Rentable.initialize.selector,
                        governance,
                        operator
                    )
                )
            )
        );

        orentableLogic = new ORentable(
            address(testNFT),
            address(0),
            address(0)
        );

        obeacon = new UpgradeableBeacon(address(orentableLogic));

        orentable = ORentable(
            address(
                new ImmutableAdminUpgradeableBeaconProxy(
                    address(obeacon),
                    address(proxyAdmin),
                    abi.encodeWithSelector(
                        BaseTokenInitializable.initialize.selector,
                        address(testNFT),
                        governance,
                        address(rentable)
                    )
                )
            )
        );

        rentable.setORentable(address(testNFT), address(orentable));

        wrentableLogic = new WRentable(
            address(testNFT),
            address(0),
            address(0)
        );

        wbeacon = new UpgradeableBeacon(address(wrentableLogic));

        wrentable = WRentable(
            address(
                new ImmutableAdminUpgradeableBeaconProxy(
                    address(wbeacon),
                    address(proxyAdmin),
                    abi.encodeWithSelector(
                        BaseTokenInitializable.initialize.selector,
                        address(testNFT),
                        governance,
                        address(rentable)
                    )
                )
            )
        );

        rentable.setWRentable(address(testNFT), address(wrentable));

        rentable.enablePaymentToken(address(0));
        rentable.enablePaymentToken(address(weth));
        rentable.enablePaymentToken(address(dummy1155));

        rentable.setFeeCollector(feeCollector);

        rentable.setLibrary(address(testNFT), address(dummyLib));

        vm.stopPrank();
    }

    function prepareTestDeposit(uint256 tokenId) internal {
        testNFT.mint(user, tokenId);
    }

    function depositAndApprove(
        address _user,
        uint256 value,
        address paymentToken,
        uint256 paymentTokenId
    ) public {
        vm.deal(_user, value);
        if (paymentToken == address(weth)) {
            weth.deposit{value: value}();
            weth.approve(address(rentable), ~uint256(0));
        } else if (paymentToken == address(dummy1155)) {
            dummy1155.deposit{value: value}(paymentTokenId);
            dummy1155.setApprovalForAll(address(rentable), true);
        }
    }

    function getBalance(
        address user,
        address paymentToken,
        uint256 _paymentTokenId
    ) public view returns (uint256) {
        if (paymentToken == address(weth)) {
            return weth.balanceOf(user);
        } else if (paymentToken == address(dummy1155)) {
            return dummy1155.balanceOf(user, _paymentTokenId);
        } else {
            return user.balance;
        }
    }
}
