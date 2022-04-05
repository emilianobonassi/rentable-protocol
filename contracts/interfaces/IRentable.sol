// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IRentableEvents} from "./IRentableEvents.sol";
import {RentableTypes} from "../RentableTypes.sol";

interface IRentable is IRentableEvents {
    /* FLOWS

        A. To deposit an NFT w/o listing:
        - Call safeTransferFrom(ownerAddress, rentableAddress, data) on the NFT contract with empty data
        
        B. To deposit and list (i.e. set price and max duration) an NFT:
        - Encode listing info (RentableConditions). 
        - Call safeTransferFrom(ownerAddress, rentableAddress, data) with data encoded before
        - This will automatically call depositAndList on Rentable without the need of approvals.

        On A - B flows, the depositor will safely receive an NFT (oToken) which represent the deposit
        Depositor, if smart contract, must implement IERC721Receiver
        https://docs.openzeppelin.com/contracts/2.x/api/token/erc721#IERC721Receiver

        C. To update rental conditions for an NFT
        - Call createOrUpdateRentalConditions

        D. To unlist an NFT
        - Call deleteRentalConditions

        E. To withdraw the NFT
        - Call withdraw

        When renter renter the asset, the owner receives the full amount payed by the renter
    */

    /**  
        @dev Withdraws the specified NFT if the caller owns the respective oToken
        @param tokenAddress The address of the NFT smart contract to withdraw
        @param tokenId The token id of the NFT smart contract to withdraw
    */
    function withdraw(address tokenAddress, uint256 tokenId) external;

    /**  
        @dev Lists an NFT with specified conditions or, if already listed, updates the conditions
        @param tokenAddress The address of the NFT smart contract to deposit and list
        @param tokenId The token id of the NFT smart contract to deposit and list
        @param rentalConditions_ rental conditions see RentableTypes.RentalConditions
    */
    function createOrUpdateRentalConditions(
        address tokenAddress,
        uint256 tokenId,
        RentableTypes.RentalConditions calldata rentalConditions_
    ) external;

    function rentalConditions(address tokenAddress, uint256 tokenId)
        external
        view
        returns (RentableTypes.RentalConditions memory);

    function rent(
        address tokenAddress,
        uint256 tokenId,
        uint256 duration
    ) external payable;

    /**  
        @dev Unlists an NFT from Rentable (the NFT remains deposited)
        @param tokenAddress The address of the NFT smart contract to deposit and list
        @param tokenId The token id of the NFT smart contract to deposit and list
    **/
    function deleteRentalConditions(address tokenAddress, uint256 tokenId)
        external;

    function expiresAt(address tokenAddress, uint256 tokenId)
        external
        view
        returns (uint256);

    function expireRental(address tokenAddress, uint256 tokenId) external;

    function expireRentals(
        address[] calldata tokenAddresses,
        uint256[] calldata tokenIds
    ) external;
}
