// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IRentable {
    struct RentalConditions {
        uint256 maxTimeDuration;
        uint256 pricePerSecond;
        uint256 paymentTokenId;
        address paymentTokenAddress;
        address privateRenter;
    }

    /* FLOWS

        A. To deposit an NFT w/o listing:
        - Call safeTransferFrom(ownerAddress, rentableAddress, data) on the NFT contract with empty data
        
        B. To deposit and list (i.e. set price and max duration) an NFT:
        - Encode listing info: paymentTokenAddress (address), paymentTokenId (uint256), maxTimeDuration (uint256), pricePerBlock (uint256), privateRenter (address) as documented in function depositAndList. 
        - Call safeTransferFrom(ownerAddress, rentableAddress, data) with data encoded before
        - This will automatically call depositAndList on Rentable without the need of approvals.
        OR (not preferred)
        - Call approve(rentableAddress, tokenId) on the NFT contract
        - Call depositAndList

        On A - B flows, the depositor will safely receive an NFT (oToken) which represent the deposit
        Depositor, if smart contract, must implement IERC721Receiver - https://docs.openzeppelin.com/contracts/2.x/api/token/erc721#IERC721Receiver

        C. To update rental conditions for an NFT
        - Call createOrUpdateRentalConditions

        D. To unlist an NFT
        - Call deleteRentalConditions

        E. To withdraw the NFT
        - Call withdraw

        When renter renter the asset, the owner receives the full amount payed by the renter
    */

    /**  
        @dev Deposits an NFT into the Rentable smart contract (without listing it), trasfers an oToken to the caller
        @param tokenAddress The address of the NFT smart contract to deposit
        @param tokenId The token id of the NFT smart contract to deposit
        @return The tokenId of the transferred oToken (equals to tokenId deposited)
    */
    function deposit(address tokenAddress, uint256 tokenId)
        external
        returns (uint256);

    /**  
        @dev Deposits an NFT into the Rentable smart contract and list it with specified conditions. 
             Trasfers an oToken to the caller (combines deposit and createOrUpdateRentalConditions)
        @param tokenAddress The address of the NFT smart contract to deposit and list
        @param tokenId The token id of the NFT smart contract to deposit and list
        @param paymentTokenAddress The address of the token to use as currency for payments (use address(0) for ETH)
        @param paymentTokenId The token id of the payment token (ERC1555 ONLY, use 0 otherwise)
        @param maxTimeDuration The maximum duration of a single rental in numbers of blocks
        @param pricePerBlock The price of rental per block in the specified currency
        @param privateRenter The address of the user that reserved the rental (use address(0) for public rentals)
        @return The tokenId of the transferred oToken (equals to tokenId)
    */
    function depositAndList(
        address tokenAddress,
        uint256 tokenId,
        address paymentTokenAddress,
        uint256 paymentTokenId,
        uint256 maxTimeDuration,
        uint256 pricePerBlock,
        address privateRenter
    ) external returns (uint256);

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
        @param paymentTokenAddress The address of the token to use as currency for payments (use address(0) for ETH)
        @param paymentTokenId The token id of the payment token (ERC1555 ONLY, use 0 otherwise)
        @param maxTimeDuration The maximum duration of a single rental in numbers of blocks
        @param pricePerBlock The price of rental per block in the specified currency
        @param privateRenter The address of the user that reserved the rental (use address(0) for public rentals)

    */
    function createOrUpdateRentalConditions(
        address tokenAddress,
        uint256 tokenId,
        address paymentTokenAddress,
        uint256 paymentTokenId,
        uint256 maxTimeDuration,
        uint256 pricePerBlock,
        address privateRenter
    ) external;

    function rentalConditions(address tokenAddress, uint256 tokenId)
        external
        view
        returns (RentalConditions memory);

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
