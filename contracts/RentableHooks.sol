// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/Address.sol";
import "./collectionlibs/ICollectionLibrary.sol";

contract RentableHooks {
    using Address for address;

    mapping(address => address) internal _libraries;

    function getLibrary(address wrapped_) external view returns (address) {
        return _libraries[wrapped_];
    }

    function setLibrary(address wrapped_, address library_) external {
        _libraries[wrapped_] = library_;
    }

    function _postDeposit(
        address tokenAddress,
        uint256 tokenId,
        address user
    ) internal {
        address lib = _libraries[tokenAddress];
        if (lib != address(0)) {
            lib.functionDelegateCall(
                abi.encodeCall(
                    ICollectionLibrary(lib).postDeposit,
                    (tokenAddress, tokenId, user)
                ),
                ""
            );
        }
    }

    function _postList(
        address tokenAddress,
        uint256 tokenId,
        address user,
        uint256 maxTimeDuration,
        uint256 pricePerSecond
    ) internal {
        address lib = _libraries[tokenAddress];
        if (lib != address(0)) {
            lib.functionDelegateCall(
                abi.encodeCall(
                    ICollectionLibrary(lib).postList,
                    (
                        tokenAddress,
                        tokenId,
                        user,
                        maxTimeDuration,
                        pricePerSecond
                    )
                ),
                ""
            );
        }
    }

    function _postCreateRent(
        address tokenAddress,
        uint256 tokenId,
        uint256 duration,
        address from,
        address to
    ) internal {
        address lib = _libraries[tokenAddress];
        if (lib != address(0)) {
            lib.functionDelegateCall(
                abi.encodeCall(
                    ICollectionLibrary(lib).postCreateRent,
                    (tokenAddress, tokenId, duration, from, to)
                ),
                ""
            );
        }
    }

    function _postexpireRental(
        address tokenAddress,
        uint256 tokenId,
        address from,
        address to
    ) internal {
        address lib = _libraries[tokenAddress];
        if (lib != address(0)) {
            lib.functionDelegateCall(
                abi.encodeCall(
                    ICollectionLibrary(lib).postexpireRental,
                    (tokenAddress, tokenId, from, to)
                ),
                ""
            );
        }
    }
}
