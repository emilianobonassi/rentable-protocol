// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

// Inheritance
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// References
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title Rentable account abstraction
/// @author Rentable Team <hello@rentable.world>
/// @notice Account Abstraction
contract SimpleWallet is ERC721Holder, Ownable {
    /* ========== LIBRARIES ========== */

    using ECDSA for bytes32;

    /* ========== CONSTANTS ========== */

    bytes4 private constant ERC1271_IS_VALID_SIGNATURE =
        bytes4(keccak256("isValidSignature(bytes32,bytes)"));

    /* ========== STATE VARIABLES ========== */

    // current owner for the content
    address private _user;

    /* ========== SETTERS ========== */

    /// @notice Set current user for the wallet
    /// @param user user address
    function setUser(address user) external onlyOwner {
        // it's ok to se to 0x0, disabling signatures
        // slither-disable-next-line missing-zero-check
        _user = user;
    }

    /* ========== VIEWS ========== */

    /// @notice Set current user for the wallet
    /// @return user address
    function getUser() external view returns (address user) {
        return _user;
    }

    /// @notice Implementation of EIP 1271.
    /// Should return whether the signature provided is valid for the provided data.
    /// @param msgHash Hash of a message signed on the behalf of address(this)
    /// @param signature Signature byte array associated with _msgHash
    function isValidSignature(bytes32 msgHash, bytes memory signature)
        external
        view
        returns (bytes4)
    {
        // For the first implementation
        // we won't recursively check if user is smart wallet too
        // we assume user is an EOA
        address signer = msgHash.recover(signature);
        require(_user == signer, "Invalid signer");
        return ERC1271_IS_VALID_SIGNATURE;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice Withdraw asset ERC721
    /// @param assetAddress token address
    /// @param tokenId token id
    function withdrawERC721(
        address assetAddress,
        uint256 tokenId,
        bool notSafe
    ) external onlyOwner {
        if (notSafe) {
            // slither-disable-next-line calls-loop
            IERC721(assetAddress).transferFrom(
                address(this),
                msg.sender,
                tokenId
            );
        } else {
            // slither-disable-next-line calls-loop
            IERC721(assetAddress).safeTransferFrom(
                address(this),
                msg.sender,
                tokenId
            );
        }
    }
}
