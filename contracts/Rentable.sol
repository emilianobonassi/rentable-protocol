// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {BaseSecurityInitializable} from "./utils/BaseSecurityInitializable.sol";
import "./IERC721ReadOnlyProxy.sol";
import {ICollectionLibrary} from "./collectionlibs/ICollectionLibrary.sol";
import {IRentable} from "./IRentable.sol";
import "./WRentable.sol";
import "./IORentableHooks.sol";
import "./IWRentableHooks.sol";
import {RentableStorageV1} from "./RentableStorageV1.sol";

contract Rentable is
    IRentable,
    IORentableHooks,
    IWRentableHooks,
    IERC721Receiver,
    BaseSecurityInitializable,
    ReentrancyGuard,
    RentableStorageV1
{
    using Address for address;
    using SafeERC20 for IERC20;

    constructor(address _governance, address _operator) {
        _initialize(_governance, _operator);
    }

    function initialize(address _governance, address _operator) external {
        _initialize(_governance, _operator);
    }

    function _initialize(address _governance, address _operator)
        internal
        initializer
    {
        __BaseSecurityInitializable_init(_governance, _operator);
    }

    function getORentable(address wrapped_)
        external
        view
        virtual
        returns (address)
    {
        return address(_orentables[wrapped_]);
    }

    function setORentable(address wrapped_, address oRentable_)
        external
        onlyGovernance
    {
        _orentables[wrapped_] = IERC721ReadOnlyProxy(oRentable_);
    }

    function getWRentable(address wrapped_) external view returns (address) {
        return address(_wrentables[wrapped_]);
    }

    function setWRentable(address wrapped_, address rentable_)
        external
        onlyGovernance
    {
        _wrentables[wrapped_] = rentable_;
    }

    function setFixedFee(uint256 _fixedFee) external onlyGovernance {
        fixedFee = _fixedFee;
    }

    function setFee(uint16 _fee) external onlyGovernance {
        fee = _fee;
    }

    function setFeeCollector(address payable _feeCollector)
        external
        onlyGovernance
    {
        feeCollector = _feeCollector;
    }

    function enablePaymentToken(address paymentTokenAddress)
        external
        onlyGovernance
    {
        paymentTokenAllowlist[paymentTokenAddress] = ERC20_TOKEN;
    }

    function enable1155PaymentToken(address paymentTokenAddress)
        external
        onlyGovernance
    {
        paymentTokenAllowlist[paymentTokenAddress] = ERC1155_TOKEN;
    }

    function disablePaymentToken(address paymentTokenAddress)
        external
        onlyGovernance
    {
        paymentTokenAllowlist[paymentTokenAddress] = NOT_ALLOWED_TOKEN;
    }

    function enableProxyCall(
        address caller,
        bytes4 selector,
        bool enabled
    ) external onlyGovernance {
        proxyAllowList[caller][selector] = enabled;
    }

    function isEnabledProxyCall(address caller, bytes4 selector)
        external
        view
        onlyGovernance
        returns (bool)
    {
        return proxyAllowList[caller][selector];
    }

    function _getExistingORentable(address tokenAddress)
        internal
        view
        virtual
        returns (IERC721ReadOnlyProxy oRentable)
    {
        oRentable = _orentables[tokenAddress];
        require(
            address(oRentable) != address(0),
            "Token currently not supported"
        );
    }

    function _getExistingORentableCheckOwnership(
        address tokenAddress,
        uint256 tokenId,
        address user
    ) internal virtual returns (IERC721ReadOnlyProxy oRentable) {
        oRentable = _getExistingORentable(tokenAddress);

        require(oRentable.ownerOf(tokenId) == user, "The token must be yours");
    }

    modifier onlyOTokenOwner(address tokenAddress, uint256 tokenId) {
        _getExistingORentableCheckOwnership(tokenAddress, tokenId, msg.sender);
        _;
    }

    function _deposit(
        address tokenAddress,
        uint256 tokenId,
        address to,
        bool skipTransfer
    ) internal {
        IERC721ReadOnlyProxy oRentable = _getExistingORentable(tokenAddress);

        if (!skipTransfer) {
            IERC721(tokenAddress).transferFrom(to, address(this), tokenId);
        } else {
            require(
                IERC721(tokenAddress).ownerOf(tokenId) == address(this),
                "Token not deposited"
            );
        }

        oRentable.mint(to, tokenId);

        _postDeposit(tokenAddress, tokenId, to);

        emit Deposit(to, tokenAddress, tokenId);
    }

    function _depositAndList(
        address tokenAddress,
        uint256 tokenId,
        address to,
        bool skipTransfer,
        address paymentTokenAddress,
        uint256 paymentTokenId,
        uint256 maxTimeDuration,
        uint256 pricePerSecond,
        address privateRenter
    ) internal {
        _deposit(tokenAddress, tokenId, to, skipTransfer);

        _createOrUpdateRentalConditions(
            to,
            tokenAddress,
            tokenId,
            paymentTokenAddress,
            paymentTokenId,
            maxTimeDuration,
            pricePerSecond,
            privateRenter
        );
    }

    function deposit(address tokenAddress, uint256 tokenId)
        external
        virtual
        override
        nonReentrant
        whenNotPaused
    {
        _deposit(tokenAddress, tokenId, msg.sender, false);
    }

    function depositAndList(
        address tokenAddress,
        uint256 tokenId,
        address paymentTokenAddress,
        uint256 paymentTokenId,
        uint256 maxTimeDuration,
        uint256 pricePerSecond,
        address privateRenter
    ) external virtual override nonReentrant whenNotPaused {
        _depositAndList(
            tokenAddress,
            tokenId,
            msg.sender,
            false,
            paymentTokenAddress,
            paymentTokenId,
            maxTimeDuration,
            pricePerSecond,
            privateRenter
        );
    }

    function withdraw(address tokenAddress, uint256 tokenId)
        external
        virtual
        override
        nonReentrant
        whenNotPaused
    {
        address user = msg.sender;
        IERC721ReadOnlyProxy oRentable = _getExistingORentableCheckOwnership(
            tokenAddress,
            tokenId,
            user
        );

        require(
            !_expireRental(user, tokenAddress, tokenId, false),
            "Current rent still pending"
        );

        _deleteRentalConditions(tokenAddress, tokenId);

        oRentable.burn(tokenId);

        IERC721(tokenAddress).safeTransferFrom(address(this), user, tokenId);

        emit Withdraw(tokenAddress, tokenId);
    }

    function rentalConditions(address tokenAddress, uint256 tokenId)
        external
        view
        virtual
        override
        returns (RentableTypes.RentalConditions memory)
    {
        return _rentalConditions[tokenAddress][tokenId];
    }

    function expiresAt(address tokenAddress, uint256 tokenId)
        external
        view
        virtual
        override
        returns (uint256)
    {
        return _etas[tokenAddress][tokenId];
    }

    function _createOrUpdateRentalConditions(
        address user,
        address tokenAddress,
        uint256 tokenId,
        address paymentTokenAddress,
        uint256 paymentTokenId,
        uint256 maxTimeDuration,
        uint256 pricePerSecond,
        address privateRenter
    ) internal {
        require(
            paymentTokenAllowlist[paymentTokenAddress] != NOT_ALLOWED_TOKEN,
            "Not supported payment token"
        );

        _rentalConditions[tokenAddress][tokenId] = RentableTypes
            .RentalConditions({
                maxTimeDuration: maxTimeDuration,
                pricePerSecond: pricePerSecond,
                paymentTokenAddress: paymentTokenAddress,
                paymentTokenId: paymentTokenId,
                privateRenter: privateRenter
            });

        _postList(tokenAddress, tokenId, user, maxTimeDuration, pricePerSecond);

        emit UpdateRentalConditions(
            tokenAddress,
            tokenId,
            paymentTokenAddress,
            paymentTokenId,
            maxTimeDuration,
            pricePerSecond,
            privateRenter
        );
    }

    function _expireRental(
        address oTokenOwner,
        address tokenAddress,
        uint256 tokenId,
        bool skipExistCheck
    ) internal virtual returns (bool currentlyRented) {
        if (
            skipExistCheck ||
            WRentable(_wrentables[tokenAddress]).exists(tokenId)
        ) {
            if (block.timestamp >= (_etas[tokenAddress][tokenId])) {
                address currentRentee = oTokenOwner == address(0)
                    ? IERC721ReadOnlyProxy(_orentables[tokenAddress]).ownerOf(
                        tokenId
                    )
                    : oTokenOwner;
                address currentRenter = WRentable(_wrentables[tokenAddress])
                    .ownerOf(tokenId);
                WRentable(_wrentables[tokenAddress]).burn(tokenId);
                _postexpireRental(
                    tokenAddress,
                    tokenId,
                    currentRentee,
                    currentRenter
                );
                emit RentEnds(tokenAddress, tokenId);
            } else {
                currentlyRented = true;
            }
        }

        return currentlyRented;
    }

    function createOrUpdateRentalConditions(
        address tokenAddress,
        uint256 tokenId,
        address paymentTokenAddress,
        uint256 paymentTokenId,
        uint256 maxTimeDuration,
        uint256 pricePerSecond,
        address privateRenter
    )
        external
        virtual
        override
        onlyOTokenOwner(tokenAddress, tokenId)
        whenNotPaused
    {
        _createOrUpdateRentalConditions(
            msg.sender,
            tokenAddress,
            tokenId,
            paymentTokenAddress,
            paymentTokenId,
            maxTimeDuration,
            pricePerSecond,
            privateRenter
        );
    }

    function _deleteRentalConditions(address tokenAddress, uint256 tokenId)
        internal
    {
        (_rentalConditions[tokenAddress][tokenId]).maxTimeDuration = 0;
    }

    function deleteRentalConditions(address tokenAddress, uint256 tokenId)
        external
        virtual
        override
        onlyOTokenOwner(tokenAddress, tokenId)
        whenNotPaused
    {
        _deleteRentalConditions(tokenAddress, tokenId);
    }

    function rent(
        address tokenAddress,
        uint256 tokenId,
        uint256 duration
    ) external payable virtual override nonReentrant whenNotPaused {
        IERC721ReadOnlyProxy oRentable = _getExistingORentable(tokenAddress);
        address payable rentee = payable(oRentable.ownerOf(tokenId));

        RentableTypes.RentalConditions memory rcs = _rentalConditions[
            tokenAddress
        ][tokenId];
        require(rcs.maxTimeDuration > 0, "Not available");

        require(
            !_expireRental(rentee, tokenAddress, tokenId, false),
            "Current rent still pending"
        );

        require(
            duration <= rcs.maxTimeDuration,
            "Duration greater than conditions"
        );

        require(
            rcs.privateRenter == address(0) || rcs.privateRenter == msg.sender,
            "Rental reserved for another user"
        );

        uint256 paymentQty = rcs.pricePerSecond * duration;

        // Fee calc
        uint256 feesForFeeCollector = fixedFee +
            (((paymentQty - fixedFee) * fee) / BASE_FEE);
        uint256 feesForRentee = paymentQty - feesForFeeCollector;

        uint256 eta = block.timestamp + duration;
        _etas[tokenAddress][tokenId] = eta;

        WRentable(_wrentables[tokenAddress]).mint(msg.sender, tokenId);

        if (rcs.paymentTokenAddress == address(0)) {
            require(msg.value >= paymentQty, "Not enough funds");
            if (feesForFeeCollector > 0) {
                Address.sendValue(feeCollector, feesForFeeCollector);
            }

            Address.sendValue(rentee, feesForRentee);

            if (msg.value > paymentQty) {
                Address.sendValue(payable(msg.sender), msg.value - paymentQty);
            }
        } else if (
            paymentTokenAllowlist[rcs.paymentTokenAddress] == ERC20_TOKEN
        ) {
            if (feesForFeeCollector > 0) {
                IERC20(rcs.paymentTokenAddress).safeTransferFrom(
                    msg.sender,
                    feeCollector,
                    feesForFeeCollector
                );
            }

            IERC20(rcs.paymentTokenAddress).safeTransferFrom(
                msg.sender,
                rentee,
                feesForRentee
            );
        } else {
            if (feesForFeeCollector > 0) {
                IERC1155(rcs.paymentTokenAddress).safeTransferFrom(
                    msg.sender,
                    feeCollector,
                    rcs.paymentTokenId,
                    feesForFeeCollector,
                    ""
                );
            }

            IERC1155(rcs.paymentTokenAddress).safeTransferFrom(
                msg.sender,
                rentee,
                rcs.paymentTokenId,
                feesForRentee,
                ""
            );
        }

        _postCreateRent(tokenAddress, tokenId, duration, rentee, msg.sender);

        emit Rent(
            rentee,
            msg.sender,
            tokenAddress,
            tokenId,
            rcs.paymentTokenAddress,
            rcs.paymentTokenId,
            eta
        );
    }

    function expireRental(address tokenAddress, uint256 tokenId)
        external
        virtual
        override
        whenNotPaused
    {
        _expireRental(address(0), tokenAddress, tokenId, false);
    }

    function expireRentals(
        address[] calldata tokenAddresses,
        uint256[] calldata tokenIds
    ) external virtual override whenNotPaused {
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            _expireRental(address(0), tokenAddresses[i], tokenIds[i], false);
        }
    }

    function afterWTokenTransfer(
        address tokenAddress,
        address from,
        address to,
        uint256 tokenId
    ) external virtual override whenNotPaused {
        require(
            msg.sender == _wrentables[tokenAddress],
            "Only proper WRentables allowed"
        );

        _expireRental(address(0), tokenAddress, tokenId, true);

        address lib = _libraries[tokenAddress];
        if (lib != address(0)) {
            lib.functionDelegateCall(
                abi.encodeCall(
                    ICollectionLibrary(lib).postWTokenTransfer,
                    (tokenAddress, tokenId, from, to)
                ),
                ""
            );
        }
    }

    function afterOTokenTransfer(
        address tokenAddress,
        address from,
        address to,
        uint256 tokenId
    ) external virtual override whenNotPaused {
        require(
            msg.sender == address(_orentables[tokenAddress]),
            "Only proper ORentables allowed"
        );

        bool rented = _expireRental(from, tokenAddress, tokenId, false);

        address lib = _libraries[tokenAddress];
        if (lib != address(0)) {
            lib.functionDelegateCall(
                abi.encodeCall(
                    ICollectionLibrary(lib).postOTokenTransfer,
                    (tokenAddress, tokenId, from, to, rented)
                ),
                ""
            );
        }
    }

    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) public virtual override nonReentrant whenNotPaused returns (bytes4) {
        if (data.length == 0) {
            _deposit(msg.sender, tokenId, from, true);
        } else {
            RentableTypes.RentalConditions memory rc = abi.decode(
                data,
                (RentableTypes.RentalConditions)
            );

            _depositAndList(
                msg.sender,
                tokenId,
                from,
                true,
                rc.paymentTokenAddress,
                rc.paymentTokenId,
                rc.maxTimeDuration,
                rc.pricePerSecond,
                rc.privateRenter
            );
        }

        return this.onERC721Received.selector;
    }

    function proxyCall(
        address to,
        uint256 value,
        bytes4 selector,
        bytes memory data
    ) external payable returns (bytes memory) {
        require(
            msg.sender == address(_orentables[to]) ||
                msg.sender == _wrentables[to],
            "Only w/o tokens are authorized"
        );

        require(
            proxyAllowList[msg.sender][selector],
            "Proxy call unauthorized"
        );

        return
            to.functionCallWithValue(
                abi.encodePacked(selector, data),
                value,
                ""
            );
    }

    function getLibrary(address wrapped_) external view returns (address) {
        return _libraries[wrapped_];
    }

    function setLibrary(address wrapped_, address library_)
        external
        onlyGovernance
    {
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
