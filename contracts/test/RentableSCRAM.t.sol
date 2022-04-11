// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.7;

import {TestLand} from "./mocks/TestLand.sol";

import {SharedSetup, Vm} from "./SharedSetup.t.sol";

import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

import {DecentralandCollectionLibrary} from "../collections/decentraland/DecentralandCollectionLibrary.sol";
import {ICollectionLibrary} from "../collections/ICollectionLibrary.sol";
import {IRentable} from "../interfaces/IRentable.sol";

import {RentableTypes} from "./../RentableTypes.sol";

import {ORentable} from "../tokenization/ORentable.sol";
import {WRentable} from "../tokenization/WRentable.sol";

contract RentableSCRAM is SharedSetup {
    function testSCRAM() public executeByUser(user) {
        //2 subscription, SCRAM, operation stopped, safe withdrawal by governance
        address renter = vm.addr(10);

        uint256 tokenId = 123;
        testNFT.mint(user, tokenId);
        testNFT.mint(user, tokenId + 1);
        testNFT.mint(user, tokenId + 2);

        testNFT.approve(address(rentable), tokenId);
        testNFT.approve(address(rentable), tokenId + 1);

        testNFT.safeTransferFrom(user, address(rentable), tokenId);
        testNFT.safeTransferFrom(user, address(rentable), tokenId + 1);

        uint256 maxTimeDuration = 1000;
        uint256 pricePerSecond = 0.001 ether;

        RentableTypes.RentalConditions memory rc = RentableTypes
            .RentalConditions({
                paymentTokenAddress: address(0),
                paymentTokenId: 0,
                maxTimeDuration: maxTimeDuration,
                pricePerSecond: pricePerSecond,
                privateRenter: address(0)
            });

        rentable.createOrUpdateRentalConditions(address(testNFT), tokenId, rc);

        rentable.createOrUpdateRentalConditions(
            address(testNFT),
            tokenId + 1,
            rc
        );

        uint256 rentalDuration = 70;
        uint256 value = 0.07 ether;

        depositAndApprove(renter, value, address(0), 0);

        switchUser(renter);
        rentable.rent{value: value}(address(testNFT), tokenId, rentalDuration);

        switchUser(operator);

        rentable.SCRAM();

        switchUser(user);

        assert(rentable.paused());

        vm.expectRevert(bytes("Pausable: paused"));
        rentable.withdraw(address(testNFT), tokenId);

        vm.expectRevert(bytes("Pausable: paused"));
        rentable.expireRental(address(testNFT), 1);

        vm.expectRevert(bytes("Pausable: paused"));
        orentable.transferFrom(user, operator, tokenId);

        switchUser(renter);

        vm.expectRevert(bytes("Pausable: paused"));
        wrentable.transferFrom(renter, user, tokenId);

        switchUser(user);

        vm.expectRevert(bytes("Pausable: paused"));
        testNFT.safeTransferFrom(user, address(rentable), tokenId + 2);
        /*
    Test safe withdrawal by governance
    1. exec emergency operation
    2. withdrawal single
    3. withdrawal batch
    */

        switchUser(governance);

        rentable.emergencyExecute(
            address(testNFT),
            0,
            abi.encodeWithSelector(
                IERC721Upgradeable.transferFrom.selector,
                address(rentable),
                governance,
                tokenId
            ),
            false,
            200000
        );

        assertEq(testNFT.ownerOf(tokenId), governance);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId + 1;
        rentable.emergencyBatchWithdrawERC721(address(testNFT), tokenIds, true);
        assertEq(testNFT.ownerOf(tokenId + 1), governance);
    }
}
