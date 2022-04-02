// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// Inheritance
import {IRentable} from "./interfaces/IRentable.sol";
import {IORentableHooks} from "./interfaces/IORentableHooks.sol";
import {IWRentableHooks} from "./interfaces/IWRentableHooks.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {BaseSecurityInitializable} from "./upgradability/BaseSecurityInitializable.sol";
import {RentableStorageV1} from "./RentableStorageV1.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Libraries
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

// References
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC721ReadOnlyProxy} from "./interfaces/IERC721ReadOnlyProxy.sol";
import {ICollectionLibrary} from "./collections/ICollectionLibrary.sol";
import {RentableTypes} from "./RentableTypes.sol";
import {WRentable} from "./tokenization/WRentable.sol";

/// @title Rentable main contract
/// @author Rentable Team <hello@rentable.world>
/// @notice Main entry point to interact with Rentable protocol
contract Rentable is
    IRentable,
    IORentableHooks,
    IWRentableHooks,
    IERC721Receiver,
    BaseSecurityInitializable,
    ReentrancyGuard,
    RentableStorageV1
{
    /* ========== LIBRARIES ========== */

    using Address for address;
    using SafeERC20 for IERC20;

    /* ========== MODIFIERS ========== */

    /// @dev Prevents calling a function from anyone except the owner
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    modifier onlyOTokenOwner(address tokenAddress, uint256 tokenId) {
        _getExistingORentableCheckOwnership(tokenAddress, tokenId, msg.sender);
        _;
    }

    /// @dev Prevents calling a function from anyone except respective OToken
    /// @param tokenAddress wrapped token address
    modifier onlyOToken(address tokenAddress) {
        require(
            msg.sender == address(_orentables[tokenAddress]),
            "Only proper ORentables allowed"
        );
        _;
    }

    /// @dev Prevents calling a function from anyone except respective WToken
    /// @param tokenAddress wrapped token address
    modifier onlyWToken(address tokenAddress) {
        require(
            msg.sender == _wrentables[tokenAddress],
            "Only proper WRentables allowed"
        );
        _;
    }

    /// @dev Prevents calling a function from anyone except respective OToken or WToken
    /// @param tokenAddress wrapped token address
    modifier onlyOTokenOrWToken(address tokenAddress) {
        require(
            msg.sender == address(_orentables[tokenAddress]) ||
                msg.sender == _wrentables[tokenAddress],
            "Only w/o tokens are authorized"
        );
        _;
    }

    /* ========== CONSTRUCTOR ========== */

    /// @dev Instatiate Rentable
    /// @param _governance address for governance role
    /// @param _operator address for operator role
    constructor(address _governance, address _operator) {
        _initialize(_governance, _operator);
    }

    /* ---------- INITIALIZER ---------- */

    /// @dev Initialize Rentable (to be used with proxies)
    /// @param _governance address for governance role
    /// @param _operator address for operator role
    function initialize(address _governance, address _operator) external {
        _initialize(_governance, _operator);
    }

    /// @dev For internal usage in the initializer external method
    /// @param _governance address for governance role
    /// @param _operator address for operator role
    function _initialize(address _governance, address _operator)
        internal
        initializer
    {
        __BaseSecurityInitializable_init(_governance, _operator);
    }

    /* ========== SETTERS ========== */

    /// @dev Associate the event hooks library to the specific wrapped token
    /// @param _tokenAddress wrapped token address
    /// @param _library library address
    function setLibrary(address _tokenAddress, address _library)
        external
        onlyGovernance
    {
        _libraries[_tokenAddress] = _library;
    }

    /// @dev Associate the otoken to the specific wrapped token
    /// @param _tokenAddress wrapped token address
    /// @param _oRentable otoken address
    function setORentable(address _tokenAddress, address _oRentable)
        external
        onlyGovernance
    {
        _orentables[_tokenAddress] = IERC721ReadOnlyProxy(_oRentable);
    }

    /// @dev Associate the otoken to the specific wrapped token
    /// @param _tokenAddress wrapped token address
    /// @param _wRentable otoken address
    function setWRentable(address _tokenAddress, address _wRentable)
        external
        onlyGovernance
    {
        _wrentables[_tokenAddress] = _wRentable;
    }

    /// @dev Set fixed absolute fee
    /// @param _fixedFee fixed fee in 1e18 units
    function setFixedFee(uint256 _fixedFee) external onlyGovernance {
        fixedFee = _fixedFee;
    }

    /// @dev Set fee (percentage)
    /// @param _fee fee in 1e4 units (e.g. 100% = 10000)
    function setFee(uint16 _fee) external onlyGovernance {
        fee = _fee;
    }

    /// @dev Set fee collector address
    /// @param _feeCollector fee collector address
    function setFeeCollector(address payable _feeCollector)
        external
        onlyGovernance
    {
        feeCollector = _feeCollector;
    }

    /// @dev Enable payment token (ERC20)
    /// @param _paymentTokenAddress payment token address
    function enablePaymentToken(address _paymentTokenAddress)
        external
        onlyGovernance
    {
        paymentTokenAllowlist[_paymentTokenAddress] = ERC20_TOKEN;
    }

    /// @dev Enable payment token (ERC1155)
    /// @param _paymentTokenAddress payment token address
    function enable1155PaymentToken(address _paymentTokenAddress)
        external
        onlyGovernance
    {
        paymentTokenAllowlist[_paymentTokenAddress] = ERC1155_TOKEN;
    }

    /// @dev Disable payment token (ERC1155)
    /// @param _paymentTokenAddress payment token address
    function disablePaymentToken(address _paymentTokenAddress)
        external
        onlyGovernance
    {
        paymentTokenAllowlist[_paymentTokenAddress] = NOT_ALLOWED_TOKEN;
    }

    /// @dev Toggle o/w token to call on-behalf a selector on the wrapped token
    /// @param _caller o/w token address
    /// @param _selector selector bytes on the target wrapped token
    /// @param _enabled true to enable, false to disable
    function enableProxyCall(
        address _caller,
        bytes4 _selector,
        bool _enabled
    ) external onlyGovernance {
        proxyAllowList[_caller][_selector] = _enabled;
    }

    /* ========== VIEWS ========== */

    /* ---------- Internal ---------- */

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

    /* ---------- Public ---------- */

    function getLibrary(address wrapped_) external view returns (address) {
        return _libraries[wrapped_];
    }

    function getORentable(address wrapped_)
        external
        view
        virtual
        returns (address)
    {
        return address(_orentables[wrapped_]);
    }

    function getWRentable(address wrapped_) external view returns (address) {
        return address(_wrentables[wrapped_]);
    }

    function isEnabledProxyCall(address caller, bytes4 selector)
        external
        view
        onlyGovernance
        returns (bool)
    {
        return proxyAllowList[caller][selector];
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

    /* ========== MUTATIVE FUNCTIONS ========== */

    /* ---------- Internal ---------- */

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

    function _deleteRentalConditions(address tokenAddress, uint256 tokenId)
        internal
    {
        (_rentalConditions[tokenAddress][tokenId]).maxTimeDuration = 0;
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
                _postExpireRental(
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

    modifier skipIfLibraryNotSet(address tokenAddress) {
        address lib = _libraries[tokenAddress];
        if (lib != address(0)) {
            _;
        }
    }

    function _postDeposit(
        address tokenAddress,
        uint256 tokenId,
        address user
    ) internal skipIfLibraryNotSet(tokenAddress) {
        _libraries[tokenAddress].functionDelegateCall(
            abi.encodeCall(
                ICollectionLibrary.postDeposit,
                (tokenAddress, tokenId, user)
            ),
            ""
        );
    }

    function _postList(
        address tokenAddress,
        uint256 tokenId,
        address user,
        uint256 maxTimeDuration,
        uint256 pricePerSecond
    ) internal skipIfLibraryNotSet(tokenAddress) {
        _libraries[tokenAddress].functionDelegateCall(
            abi.encodeCall(
                ICollectionLibrary.postList,
                (tokenAddress, tokenId, user, maxTimeDuration, pricePerSecond)
            ),
            ""
        );
    }

    function _postRent(
        address tokenAddress,
        uint256 tokenId,
        uint256 duration,
        address from,
        address to
    ) internal skipIfLibraryNotSet(tokenAddress) {
        _libraries[tokenAddress].functionDelegateCall(
            abi.encodeCall(
                ICollectionLibrary.postRent,
                (tokenAddress, tokenId, duration, from, to)
            ),
            ""
        );
    }

    function _postExpireRental(
        address tokenAddress,
        uint256 tokenId,
        address from,
        address to
    ) internal skipIfLibraryNotSet(tokenAddress) {
        _libraries[tokenAddress].functionDelegateCall(
            abi.encodeCall(
                ICollectionLibrary.postExpireRental,
                (tokenAddress, tokenId, from, to)
            ),
            ""
        );
    }

    /* ---------- Public ---------- */

    function deposit(address tokenAddress, uint256 tokenId)
        external
        virtual
        override
        whenNotPaused
        nonReentrant
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
    ) external virtual override whenNotPaused nonReentrant {
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

    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) public virtual override whenNotPaused nonReentrant returns (bytes4) {
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

    function withdraw(address tokenAddress, uint256 tokenId)
        external
        virtual
        override
        whenNotPaused
        nonReentrant
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
        whenNotPaused
        onlyOTokenOwner(tokenAddress, tokenId)
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

    function deleteRentalConditions(address tokenAddress, uint256 tokenId)
        external
        virtual
        override
        whenNotPaused
        onlyOTokenOwner(tokenAddress, tokenId)
    {
        _deleteRentalConditions(tokenAddress, tokenId);
    }

    function rent(
        address tokenAddress,
        uint256 tokenId,
        uint256 duration
    ) external payable virtual override whenNotPaused nonReentrant {
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

        _postRent(tokenAddress, tokenId, duration, rentee, msg.sender);

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

    /* ---------- Public Permissioned ---------- */

    function afterOTokenTransfer(
        address tokenAddress,
        address from,
        address to,
        uint256 tokenId
    ) external virtual override whenNotPaused onlyOToken(tokenAddress) {
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

    function afterWTokenTransfer(
        address tokenAddress,
        address from,
        address to,
        uint256 tokenId
    ) external virtual override whenNotPaused onlyWToken(tokenAddress) {
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

    function proxyCall(
        address to,
        uint256 value,
        bytes4 selector,
        bytes memory data
    )
        external
        payable
        whenNotPaused
        onlyOTokenOrWToken(to)
        returns (bytes memory)
    {
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
}
