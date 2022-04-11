// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.7;
import {SharedSetup} from "./SharedSetup.t.sol";

import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

import {RentableTypes} from "./../RentableTypes.sol";

import {ORentable} from "../tokenization/ORentable.sol";
import {WRentable} from "../tokenization/WRentable.sol";

contract RentableSCRAM is SharedSetup {
    function testSCRAM() public executeByUser(user) {
        //2 subscription, SCRAM, operation stopped, safe withdrawal by governance
        address renter = getNewAddress();

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

        assert(rentable.paused());

        switchUser(user);

        // onERC721Received
        vm.expectRevert(bytes("Pausable: paused"));
        rentable.onERC721Received(address(0), address(0), 0, "");

        // withdraw
        vm.expectRevert(bytes("Pausable: paused"));
        rentable.withdraw(address(testNFT), tokenId);

        // createOrUpdateRentalConditions
        vm.expectRevert(bytes("Pausable: paused"));
        rentable.createOrUpdateRentalConditions(address(testNFT), tokenId, rc);

        // deleteRentalConditions
        vm.expectRevert(bytes("Pausable: paused"));
        rentable.deleteRentalConditions(address(testNFT), tokenId);

        // rent
        depositAndApprove(renter, value, address(0), 0);
        switchUser(renter);
        vm.expectRevert(bytes("Pausable: paused"));
        rentable.rent{value: value}(address(testNFT), tokenId, rentalDuration);

        switchUser(user);
        // expireRental
        vm.expectRevert(bytes("Pausable: paused"));
        rentable.expireRental(address(testNFT), 1);
        /*
        proxyCall
        */

        // expireRentals
        address[] memory addressesToExpire = new address[](1);
        addressesToExpire[0] = address(testNFT);
        uint256[] memory idsToExpire = new uint256[](1);
        idsToExpire[0] = 1;
        vm.expectRevert(bytes("Pausable: paused"));
        rentable.expireRentals(addressesToExpire, idsToExpire);

        // afterOTokenTransfer
        vm.expectRevert(bytes("Pausable: paused"));
        rentable.afterOTokenTransfer(address(0), address(0), address(0), 0);
        vm.expectRevert(bytes("Pausable: paused"));
        orentable.transferFrom(user, operator, tokenId);

        // afterWTokenTransfer
        switchUser(renter);
        vm.expectRevert(bytes("Pausable: paused"));
        rentable.afterWTokenTransfer(address(0), address(0), address(0), 0);
        vm.expectRevert(bytes("Pausable: paused"));
        wrentable.transferFrom(renter, user, tokenId);

        // proxyCall
        vm.expectRevert(bytes("Pausable: paused"));
        rentable.proxyCall(address(0), 0, "", "");

        switchUser(user);

        /*
            Test safe withdrawal by governance
            1. exec emergency operation
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
            false
        );

        assertEq(testNFT.ownerOf(tokenId), governance);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId + 1;
        rentable.emergencyBatchWithdrawERC721(address(testNFT), tokenIds, true);
        assertEq(testNFT.ownerOf(tokenId + 1), governance);
    }
}
