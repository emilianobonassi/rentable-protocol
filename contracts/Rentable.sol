// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

// Inheritance
import {IRentable} from "./interfaces/IRentable.sol";
import {IRentableAdminEvents} from "./interfaces/IRentableAdminEvents.sol";
import {IRentableHooks} from "./interfaces/IRentableHooks.sol";
import {IORentableHooks} from "./interfaces/IORentableHooks.sol";
import {IWRentableHooks} from "./interfaces/IWRentableHooks.sol";
import {BaseSecurityInitializable} from "./security/BaseSecurityInitializable.sol";
import {RentableStorageV1} from "./RentableStorageV1.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

// Libraries
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

// References
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import {IERC721ReadOnlyProxy} from "./interfaces/IERC721ReadOnlyProxy.sol";
import {IERC721ExistExtension} from "./interfaces/IERC721ExistExtension.sol";
import {ICollectionLibrary} from "./collections/ICollectionLibrary.sol";
import {RentableTypes} from "./RentableTypes.sol";

/// @title Rentable main contract
/// @author Rentable Team <hello@rentable.world>
/// @notice Main entry point to interact with Rentable protocol
contract Rentable is
    IRentable,
    IRentableAdminEvents,
    IORentableHooks,
    IWRentableHooks,
    BaseSecurityInitializable,
    ReentrancyGuardUpgradeable,
    RentableStorageV1
{
    /* ========== LIBRARIES ========== */

    using Address for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;

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
            msg.sender == _orentables[tokenAddress],
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
            msg.sender == _orentables[tokenAddress] ||
                msg.sender == _wrentables[tokenAddress],
            "Only w/o tokens are authorized"
        );
        _;
    }

    /// @dev Prevents calling a library when not set for the respective wrapped token
    /// @param tokenAddress wrapped token address
    // slither-disable-next-line incorrect-modifier
    modifier skipIfLibraryNotSet(address tokenAddress) {
        if (_libraries[tokenAddress] != address(0)) {
            _;
        }
    }

    /* ========== CONSTRUCTOR ========== */

    /// @dev Instatiate Rentable
    /// @param governance address for governance role
    /// @param operator address for operator role
    constructor(address governance, address operator) {
        _initialize(governance, operator);
    }

    /* ---------- INITIALIZER ---------- */

    /// @dev Initialize Rentable (to be used with proxies)
    /// @param governance address for governance role
    /// @param operator address for operator role
    function initialize(address governance, address operator) external {
        _initialize(governance, operator);
    }

    /// @dev For internal usage in the initializer external method
    /// @param governance address for governance role
    /// @param operator address for operator role
    function _initialize(address governance, address operator)
        internal
        initializer
    {
        __BaseSecurityInitializable_init(governance, operator);
        __ReentrancyGuard_init();
    }

    /* ========== SETTERS ========== */

    /// @dev Associate the event hooks library to the specific wrapped token
    /// @param tokenAddress wrapped token address
    /// @param libraryAddress library address
    function setLibrary(address tokenAddress, address libraryAddress)
        external
        onlyGovernance
    {
        address previousValue = _libraries[tokenAddress];

        _libraries[tokenAddress] = libraryAddress;

        emit LibraryChanged(tokenAddress, previousValue, libraryAddress);
    }

    /// @dev Associate the otoken to the specific wrapped token
    /// @param tokenAddress wrapped token address
    /// @param oRentable otoken address
    function setORentable(address tokenAddress, address oRentable)
        external
        onlyGovernance
    {
        address previousValue = _orentables[tokenAddress];

        _orentables[tokenAddress] = oRentable;

        emit ORentableChanged(tokenAddress, previousValue, oRentable);
    }

    /// @dev Associate the otoken to the specific wrapped token
    /// @param tokenAddress wrapped token address
    /// @param wRentable otoken address
    function setWRentable(address tokenAddress, address wRentable)
        external
        onlyGovernance
    {
        address previousValue = _wrentables[tokenAddress];

        _wrentables[tokenAddress] = wRentable;

        emit WRentableChanged(tokenAddress, previousValue, wRentable);
    }

    /// @dev Set fee (percentage)
    /// @param newFee fee in 1e4 units (e.g. 100% = 10000)
    function setFee(uint16 newFee) external onlyGovernance {
        uint16 previousFee = _fee;

        _fee = newFee;

        emit FeeChanged(previousFee, newFee);
    }

    /// @dev Set fee collector address
    /// @param newFeeCollector fee collector address
    function setFeeCollector(address payable newFeeCollector)
        external
        onlyGovernance
    {
        require(newFeeCollector != address(0), "FeeCollector cannot be null");

        address previousFeeCollector = _feeCollector;

        _feeCollector = newFeeCollector;

        emit FeeCollectorChanged(previousFeeCollector, newFeeCollector);
    }

    /// @dev Enable payment token (ERC20)
    /// @param paymentToken payment token address
    function enablePaymentToken(address paymentToken) external onlyGovernance {
        uint8 previousStatus = _paymentTokenAllowlist[paymentToken];

        _paymentTokenAllowlist[paymentToken] = ERC20_TOKEN;

        emit PaymentTokenAllowListChanged(
            paymentToken,
            previousStatus,
            ERC20_TOKEN
        );
    }

    /// @dev Enable payment token (ERC1155)
    /// @param paymentToken payment token address
    function enable1155PaymentToken(address paymentToken)
        external
        onlyGovernance
    {
        uint8 previousStatus = _paymentTokenAllowlist[paymentToken];

        _paymentTokenAllowlist[paymentToken] = ERC1155_TOKEN;

        emit PaymentTokenAllowListChanged(
            paymentToken,
            previousStatus,
            ERC1155_TOKEN
        );
    }

    /// @dev Disable payment token (ERC1155)
    /// @param paymentToken payment token address
    function disablePaymentToken(address paymentToken) external onlyGovernance {
        uint8 previousStatus = _paymentTokenAllowlist[paymentToken];

        _paymentTokenAllowlist[paymentToken] = NOT_ALLOWED_TOKEN;

        emit PaymentTokenAllowListChanged(
            paymentToken,
            previousStatus,
            NOT_ALLOWED_TOKEN
        );
    }

    /// @dev Toggle o/w token to call on-behalf a selector on the wrapped token
    /// @param caller o/w token address
    /// @param selector selector bytes on the target wrapped token
    /// @param enabled true to enable, false to disable
    function enableProxyCall(
        address caller,
        bytes4 selector,
        bool enabled
    ) external onlyGovernance {
        bool previousStatus = _proxyAllowList[caller][selector];

        _proxyAllowList[caller][selector] = enabled;

        emit ProxyCallAllowListChanged(
            caller,
            selector,
            previousStatus,
            enabled
        );
    }

    /* ========== VIEWS ========== */

    /* ---------- Internal ---------- */

    /// @dev Get and check (reverting) otoken exist for a specific token
    /// @param tokenAddress wrapped token address
    /// @return oRentable otoken instance
    function _getExistingORentable(address tokenAddress)
        internal
        view
        returns (address oRentable)
    {
        oRentable = _orentables[tokenAddress];
        require(oRentable != address(0), "Token currently not supported");
    }

    /// @dev Get and check (reverting) otoken user ownership
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    /// @param user user to verify ownership
    /// @return oRentable otoken instance
    function _getExistingORentableCheckOwnership(
        address tokenAddress,
        uint256 tokenId,
        address user
    ) internal view returns (address oRentable) {
        oRentable = _getExistingORentable(tokenAddress);

        require(
            IERC721Upgradeable(oRentable).ownerOf(tokenId) == user,
            "The token must be yours"
        );
    }

    /// @dev Show rental validity
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    /// @return true if is expired, false otw
    function _isExpired(address tokenAddress, uint256 tokenId)
        internal
        view
        returns (bool)
    {
        // slither-disable-next-line timestamp
        return block.timestamp >= (_expiresAt[tokenAddress][tokenId]);
    }

    /* ---------- Public ---------- */

    /// @notice Get library address for the specific wrapped token
    /// @param tokenAddress wrapped token address
    /// @return library address
    function getLibrary(address tokenAddress) external view returns (address) {
        return _libraries[tokenAddress];
    }

    /// @notice Get OToken address associated to the specific wrapped token
    /// @param tokenAddress wrapped token address
    /// @return OToken address
    function getORentable(address tokenAddress)
        external
        view
        returns (address)
    {
        return _orentables[tokenAddress];
    }

    /// @notice Get WToken address associated to the specific wrapped token
    /// @param tokenAddress wrapped token address
    /// @return WToken address
    function getWRentable(address tokenAddress)
        external
        view
        returns (address)
    {
        return _wrentables[tokenAddress];
    }

    /// @notice Show current protocol fee
    /// @return protocol fee in 1e4 units, e.g. 100 = 1%
    function getFee() external view returns (uint16) {
        return _fee;
    }

    /// @notice Get protocol fee collector
    /// @return protocol fee collector address
    function getFeeCollector() external view returns (address payable) {
        return _feeCollector;
    }

    /// @notice Show a token is enabled as payment token
    /// @param paymentTokenAddress payment token address
    /// @return status, see RentableStorageV1 for values
    function getPaymentTokenAllowlist(address paymentTokenAddress)
        external
        view
        returns (uint8)
    {
        return _paymentTokenAllowlist[paymentTokenAddress];
    }

    /// @notice Show O/W Token can invoke selector on respective wrapped token
    /// @param caller O/W Token address
    /// @param selector function selector to invoke
    /// @return a bool representing enabled or not
    function isEnabledProxyCall(address caller, bytes4 selector)
        external
        view
        returns (bool)
    {
        return _proxyAllowList[caller][selector];
    }

    /// @inheritdoc IRentable
    function rentalConditions(address tokenAddress, uint256 tokenId)
        external
        view
        override
        returns (RentableTypes.RentalConditions memory)
    {
        return _rentalConditions[tokenAddress][tokenId];
    }

    /// @inheritdoc IRentable
    function expiresAt(address tokenAddress, uint256 tokenId)
        external
        view
        override
        returns (uint256)
    {
        return _expiresAt[tokenAddress][tokenId];
    }

    /// @inheritdoc IRentable
    function isExpired(address tokenAddress, uint256 tokenId)
        external
        view
        override
        returns (bool)
    {
        return _isExpired(tokenAddress, tokenId);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /* ---------- Internal ---------- */

    /// @dev Deposit only a wrapped token and mint respective OToken
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    /// @param to user to mint
    function _deposit(
        address tokenAddress,
        uint256 tokenId,
        address to
    ) internal {
        address oRentable = _getExistingORentable(tokenAddress);

        require(
            IERC721Upgradeable(tokenAddress).ownerOf(tokenId) == address(this),
            "Token not deposited"
        );

        IERC721ReadOnlyProxy(oRentable).mint(to, tokenId);

        _postDeposit(tokenAddress, tokenId, to);

        emit Deposit(to, tokenAddress, tokenId);
    }

    /// @dev Deposit and list a wrapped token
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    /// @param to user to mint
    /// @param rc rental conditions see RentableTypes.RentalConditions
    function _depositAndList(
        address tokenAddress,
        uint256 tokenId,
        address to,
        RentableTypes.RentalConditions memory rc
    ) internal {
        _deposit(tokenAddress, tokenId, to);

        _createOrUpdateRentalConditions(to, tokenAddress, tokenId, rc);
    }

    /// @dev Set rental conditions for a wrapped token
    /// @param user who is changing the conditions
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    /// @param rc rental conditions see RentableTypes.RentalConditions
    function _createOrUpdateRentalConditions(
        address user,
        address tokenAddress,
        uint256 tokenId,
        RentableTypes.RentalConditions memory rc
    ) internal {
        require(
            _paymentTokenAllowlist[rc.paymentTokenAddress] != NOT_ALLOWED_TOKEN,
            "Not supported payment token"
        );

        _rentalConditions[tokenAddress][tokenId] = rc;

        _postList(
            tokenAddress,
            tokenId,
            user,
            rc.maxTimeDuration,
            rc.pricePerSecond
        );

        emit UpdateRentalConditions(
            tokenAddress,
            tokenId,
            rc.paymentTokenAddress,
            rc.paymentTokenId,
            rc.maxTimeDuration,
            rc.pricePerSecond,
            rc.privateRenter
        );
    }

    /// @dev Cancel rental conditions for a wrapped token
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    function _deleteRentalConditions(address tokenAddress, uint256 tokenId)
        internal
    {
        // save gas instead of dropping all the structure
        (_rentalConditions[tokenAddress][tokenId]).maxTimeDuration = 0;
    }

    /// @dev Expire explicitely rental and update data structures for a specific wrapped token
    /// @param oTokenOwner (optional) otoken owner address
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    /// @param skipExistCheck assume or not wtoken id exists (gas optimization)
    /// @return currentlyRented true if rental is not expired
    // slither-disable-next-line calls-loop
    function _expireRental(
        address oTokenOwner,
        address tokenAddress,
        uint256 tokenId,
        bool skipExistCheck
    ) internal returns (bool currentlyRented) {
        if (
            skipExistCheck ||
            IERC721ExistExtension(_wrentables[tokenAddress]).exists(tokenId)
        ) {
            if (_isExpired(tokenAddress, tokenId)) {
                address currentRentee = oTokenOwner == address(0)
                    ? IERC721Upgradeable(_orentables[tokenAddress]).ownerOf(
                        tokenId
                    )
                    : oTokenOwner;
                IERC721ReadOnlyProxy(_wrentables[tokenAddress]).burn(tokenId);
                _postExpireRental(tokenAddress, tokenId, currentRentee);
                emit RentEnds(tokenAddress, tokenId);
            } else {
                currentlyRented = true;
            }
        }

        return currentlyRented;
    }

    /// @dev Execute custom logic after deposit via wrapped token library
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    /// @param user depositor
    function _postDeposit(
        address tokenAddress,
        uint256 tokenId,
        address user
    ) internal skipIfLibraryNotSet(tokenAddress) {
        // slither-disable-next-line unused-return
        _libraries[tokenAddress].functionDelegateCall(
            abi.encodeWithSelector(
                ICollectionLibrary.postDeposit.selector,
                tokenAddress,
                tokenId,
                user
            ),
            ""
        );
    }

    /// @dev Execute custom logic after listing via wrapped token library
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    /// @param user lister
    /// @param maxTimeDuration max duration allowed for the rental
    /// @param pricePerSecond price per second in payment token units
    function _postList(
        address tokenAddress,
        uint256 tokenId,
        address user,
        uint256 maxTimeDuration,
        uint256 pricePerSecond
    ) internal skipIfLibraryNotSet(tokenAddress) {
        // slither-disable-next-line unused-return
        _libraries[tokenAddress].functionDelegateCall(
            abi.encodeWithSelector(
                ICollectionLibrary.postList.selector,
                tokenAddress,
                tokenId,
                user,
                maxTimeDuration,
                pricePerSecond
            ),
            ""
        );
    }

    /// @dev Execute custom logic after rent via wrapped token library
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    /// @param duration rental duration
    /// @param from rentee
    /// @param to renter
    function _postRent(
        address tokenAddress,
        uint256 tokenId,
        uint256 duration,
        address from,
        address to
    ) internal skipIfLibraryNotSet(tokenAddress) {
        // slither-disable-next-line unused-return
        _libraries[tokenAddress].functionDelegateCall(
            abi.encodeWithSelector(
                ICollectionLibrary.postRent.selector,
                tokenAddress,
                tokenId,
                duration,
                from,
                to
            ),
            ""
        );
    }

    /// @dev Execute custom logic after rent expires via wrapped token library
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    /// @param from rentee
    // slither-disable-next-line calls-loop
    function _postExpireRental(
        address tokenAddress,
        uint256 tokenId,
        address from
    ) internal skipIfLibraryNotSet(tokenAddress) {
        // slither-disable-next-line unused-return
        _libraries[tokenAddress].functionDelegateCall(
            abi.encodeWithSelector(
                ICollectionLibrary.postExpireRental.selector,
                tokenAddress,
                tokenId,
                from
            ),
            ""
        );
    }

    /* ---------- Public ---------- */

    /// @inheritdoc IRentable
    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override whenNotPaused nonReentrant returns (bytes4) {
        if (data.length == 0) {
            _deposit(msg.sender, tokenId, from);
        } else {
            _depositAndList(
                msg.sender,
                tokenId,
                from,
                abi.decode(data, (RentableTypes.RentalConditions))
            );
        }

        return this.onERC721Received.selector;
    }

    /// @inheritdoc IRentable
    function withdraw(address tokenAddress, uint256 tokenId)
        external
        override
        whenNotPaused
        nonReentrant
    {
        address user = msg.sender;
        address oRentable = _getExistingORentableCheckOwnership(
            tokenAddress,
            tokenId,
            user
        );

        require(
            !_expireRental(user, tokenAddress, tokenId, false),
            "Current rent still pending"
        );

        _deleteRentalConditions(tokenAddress, tokenId);

        IERC721ReadOnlyProxy(oRentable).burn(tokenId);

        IERC721Upgradeable(tokenAddress).safeTransferFrom(
            address(this),
            user,
            tokenId
        );

        emit Withdraw(tokenAddress, tokenId);
    }

    /// @inheritdoc IRentable
    function createOrUpdateRentalConditions(
        address tokenAddress,
        uint256 tokenId,
        RentableTypes.RentalConditions calldata rc
    ) external override whenNotPaused onlyOTokenOwner(tokenAddress, tokenId) {
        _createOrUpdateRentalConditions(msg.sender, tokenAddress, tokenId, rc);
    }

    /// @inheritdoc IRentable
    function deleteRentalConditions(address tokenAddress, uint256 tokenId)
        external
        override
        whenNotPaused
        onlyOTokenOwner(tokenAddress, tokenId)
    {
        _deleteRentalConditions(tokenAddress, tokenId);
    }

    /// @inheritdoc IRentable
    function rent(
        address tokenAddress,
        uint256 tokenId,
        uint256 duration
    ) external payable override whenNotPaused nonReentrant {
        // 1. check token is deposited and available for rental
        address oRentable = _getExistingORentable(tokenAddress);
        address payable rentee = payable(
            IERC721Upgradeable(oRentable).ownerOf(tokenId)
        );

        RentableTypes.RentalConditions memory rcs = _rentalConditions[
            tokenAddress
        ][tokenId];
        require(rcs.maxTimeDuration > 0, "Not available");

        require(
            !_expireRental(rentee, tokenAddress, tokenId, false),
            "Current rent still pending"
        );

        // 2. validate renter offer with rentee conditions
        require(
            duration <= rcs.maxTimeDuration,
            "Duration greater than conditions"
        );

        require(
            rcs.privateRenter == address(0) || rcs.privateRenter == msg.sender,
            "Rental reserved for another user"
        );

        // 3. mint wtoken
        uint256 eta = block.timestamp + duration;
        _expiresAt[tokenAddress][tokenId] = eta;
        IERC721ReadOnlyProxy(_wrentables[tokenAddress]).mint(
            msg.sender,
            tokenId
        );

        // 4. fees distribution
        // gross due amount
        uint256 paymentQty = rcs.pricePerSecond * duration;
        // protocol and rentee fees calc
        uint256 feesForFeeCollector = (paymentQty * _fee) / BASE_FEE;
        uint256 feesForRentee = paymentQty - feesForFeeCollector;

        if (rcs.paymentTokenAddress == address(0)) {
            require(msg.value >= paymentQty, "Not enough funds");
            if (feesForFeeCollector > 0) {
                Address.sendValue(_feeCollector, feesForFeeCollector);
            }

            Address.sendValue(rentee, feesForRentee);

            // refund eventual remaining
            if (msg.value > paymentQty) {
                Address.sendValue(payable(msg.sender), msg.value - paymentQty);
            }
        } else if (
            _paymentTokenAllowlist[rcs.paymentTokenAddress] == ERC20_TOKEN
        ) {
            if (feesForFeeCollector > 0) {
                IERC20Upgradeable(rcs.paymentTokenAddress).safeTransferFrom(
                    msg.sender,
                    _feeCollector,
                    feesForFeeCollector
                );
            }

            IERC20Upgradeable(rcs.paymentTokenAddress).safeTransferFrom(
                msg.sender,
                rentee,
                feesForRentee
            );
        } else {
            if (feesForFeeCollector > 0) {
                IERC1155Upgradeable(rcs.paymentTokenAddress).safeTransferFrom(
                    msg.sender,
                    _feeCollector,
                    rcs.paymentTokenId,
                    feesForFeeCollector,
                    ""
                );
            }

            IERC1155Upgradeable(rcs.paymentTokenAddress).safeTransferFrom(
                msg.sender,
                rentee,
                rcs.paymentTokenId,
                feesForRentee,
                ""
            );
        }

        // 5. after rent custom logic
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

    /// @notice Trigger on-chain rental expire for expired rentals
    /// @param tokenAddress wrapped token address
    /// @param tokenId wrapped token id
    function expireRental(address tokenAddress, uint256 tokenId)
        external
        whenNotPaused
    {
        _expireRental(address(0), tokenAddress, tokenId, false);
    }

    /// @notice Batch expireRental
    /// @param tokenAddresses array of wrapped token addresses
    /// @param tokenIds array of wrapped token id
    function expireRentals(
        address[] calldata tokenAddresses,
        uint256[] calldata tokenIds
    ) external whenNotPaused {
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            _expireRental(address(0), tokenAddresses[i], tokenIds[i], false);
        }
    }

    /* ---------- Public Permissioned ---------- */

    /// @inheritdoc IORentableHooks
    function afterOTokenTransfer(
        address tokenAddress,
        address from,
        address to,
        uint256 tokenId
    ) external override whenNotPaused onlyOToken(tokenAddress) {
        bool rented = _expireRental(from, tokenAddress, tokenId, false);

        address lib = _libraries[tokenAddress];
        if (lib != address(0)) {
            // slither-disable-next-line unused-return
            lib.functionDelegateCall(
                abi.encodeWithSelector(
                    ICollectionLibrary.postOTokenTransfer.selector,
                    tokenAddress,
                    tokenId,
                    from,
                    to,
                    rented
                ),
                ""
            );
        }
    }

    /// @inheritdoc IWRentableHooks
    function afterWTokenTransfer(
        address tokenAddress,
        address from,
        address to,
        uint256 tokenId
    ) external override whenNotPaused onlyWToken(tokenAddress) {
        _expireRental(address(0), tokenAddress, tokenId, true);

        address lib = _libraries[tokenAddress];
        if (lib != address(0)) {
            // slither-disable-next-line unused-return
            lib.functionDelegateCall(
                abi.encodeWithSelector(
                    ICollectionLibrary.postWTokenTransfer.selector,
                    tokenAddress,
                    tokenId,
                    from,
                    to
                ),
                ""
            );
        }
    }

    /// @inheritdoc IRentableHooks
    function proxyCall(
        address to,
        uint256 value,
        bytes4 selector,
        bytes memory data
    )
        external
        payable
        override
        whenNotPaused
        onlyOTokenOrWToken(to) // this implicitly checks `to` is the associated wrapped token
        returns (bytes memory)
    {
        require(
            _proxyAllowList[msg.sender][selector],
            "Proxy call unauthorized"
        );

        return
            to.functionCallWithValue(bytes.concat(selector, data), value, "");
    }
}
