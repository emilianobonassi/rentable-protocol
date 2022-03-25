// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";

import {TestNFT1155} from "./utils/TestNFT1155.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {DummyERC1155} from "./utils/DummyERC1155.sol";

import {IRentable1155} from "../IRentable1155.sol";
import {Rentable1155} from "../Rentable1155.sol";
import {ORentable1155} from "../ORentable1155.sol";
import {WRentable1155} from "../WRentable1155.sol";

import {EmergencyImplementation} from "../EmergencyImplementation.sol";

interface CheatCodes {
    function prank(address) external;

    function addr(uint256) external returns (address);

    function startPrank(address) external;

    function stopPrank() external;

    function expectEmit(
        bool checkTopic1,
        bool checkTopic2,
        bool checkTopic3,
        bool checkData
    ) external;

    function expectCall(address where, bytes calldata data) external;

    function expectRevert(bytes calldata) external;

    function warp(uint256) external;

    function deal(address who, uint256 newBalance) external;

    function roll(uint256) external;
}

abstract contract SharedSetup1155 is DSTest {
    event Deposit(
        address indexed who,
        address indexed tokenAddress,
        uint256 indexed tokenId,
        uint256 amount,
        uint256 oTokenId
    );

    event UpdateRentalConditions(
        address indexed oTokenAddress,
        uint256 indexed oTokenId,
        address paymentTokenAddress,
        uint256 paymentTokenId,
        uint256 maxTimeDuration,
        uint256 pricePerBlock,
        address privateRenter
    );

    event Withdraw(
        address indexed who,
        address indexed tokenAddress,
        uint256 indexed tokenId,
        uint256 oTokenId,
        uint256 amount
    );

    event Rent(
        address from,
        address indexed to,
        address indexed tokenAddress,
        uint256 indexed oTokenId,
        uint256 wTokenId
    );

    event RentEnds(address indexed wTokenAddress, uint256 indexed wTokenId);

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    address user;

    address governance;
    address operator;
    address payable feeCollector;

    WETH weth;

    EmergencyImplementation emergencyImplementation;

    TestNFT1155 testNFT;
    DummyERC1155 dummy1155;

    Rentable1155 rentable;
    ORentable1155 orentable;
    WRentable1155 wrentable;

    function setUp() public virtual {
        governance = cheats.addr(1);
        operator = cheats.addr(2);
        feeCollector = payable(cheats.addr(3));
        user = cheats.addr(4);

        cheats.startPrank(governance);

        weth = new WETH();

        testNFT = new TestNFT1155("dummyURI");
        emergencyImplementation = new EmergencyImplementation();

        dummy1155 = new DummyERC1155();

        rentable = new Rentable1155(
            governance,
            operator,
            payable(address(emergencyImplementation))
        );

        orentable = new ORentable1155(address(testNFT), "oNFT1155", "oNFT1155");
        orentable.setRentable(address(rentable));
        rentable.setORentable(address(testNFT), address(orentable));

        wrentable = new WRentable1155(address(testNFT), "wNFT1155", "wNFT1155");
        wrentable.setRentable(address(rentable));
        rentable.setWRentable(address(testNFT), address(wrentable));

        rentable.enablePaymentToken(address(0));
        rentable.enablePaymentToken(address(weth));
        rentable.enablePaymentToken(address(dummy1155));

        rentable.setFeeCollector(feeCollector);

        cheats.stopPrank();
    }

    function mint(uint256 tokenId, uint256 mintAmount) internal {
        testNFT.mint(user, tokenId, mintAmount);
        testNFT.setApprovalForAll(address(rentable), true);
    }

    function deposit(
        uint256 tokenId,
        uint256 depositAmount,
        uint256 oTokenId
    ) internal returns (uint256) {
        return
            rentable.deposit(
                address(testNFT),
                tokenId,
                depositAmount,
                oTokenId
            );
    }

    function mintAndDeposit1155(
        uint256 tokenId,
        uint256 mintAmount,
        uint256 depositAmount,
        uint256 oTokenId
    ) internal returns (uint256) {
        mint(tokenId, mintAmount);

        return deposit(tokenId, depositAmount, oTokenId);
    }

    function depositAndApprove(
        address _user,
        uint256 value,
        address paymentToken,
        uint256 paymentTokenId
    ) public virtual {
        cheats.deal(_user, value);
        if (paymentToken == address(weth)) {
            weth.deposit{value: value}();
            weth.approve(address(rentable), ~uint256(0));
        } else if (paymentToken == address(dummy1155)) {
            dummy1155.deposit{value: value}(paymentTokenId);
            dummy1155.setApprovalForAll(address(rentable), true);
        }
    }
}
