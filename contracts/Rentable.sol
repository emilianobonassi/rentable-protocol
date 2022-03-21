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
import "@emilianobonassi-security/contracts/Security4.sol";
import "./ORentable.sol";
import "./WRentable.sol";
import "./RentableHooks.sol";

contract Rentable is
    IRentable,
    Security4,
    IERC721Receiver,
    RentableHooks,
    ReentrancyGuard
{
    using Address for address;
    using SafeERC20 for IERC20;

    struct RentalConditions {
        uint256 maxTimeDuration;
        uint256 pricePerBlock;
        uint256 paymentTokenId;
        address paymentTokenAddress;
        address privateRenter;
    }

    mapping(address => mapping(uint256 => RentalConditions))
        internal _rentalConditions;

    mapping(address => mapping(uint256 => uint256)) internal _etas;

    mapping(address => address) internal _wrentables;
    mapping(address => ORentable) internal _orentables;

    mapping(address => uint8) public paymentTokenAllowlist;

    uint8 private constant NOT_ALLOWED_TOKEN = 0;
    uint8 private constant ERC20_TOKEN = 1;
    uint8 private constant ERC1155_TOKEN = 2;

    uint16 public constant BASE_FEE = 10000;
    uint16 public fee;
    uint256 public fixedFee;

    address payable public feeCollector;

    event Deposit(
        address indexed who,
        address indexed tokenAddress,
        uint256 indexed tokenId
    );
    event UpdateRentalConditions(
        address indexed tokenAddress,
        uint256 indexed tokenId,
        address paymentTokenAddress,
        uint256 paymentTokenId,
        uint256 maxTimeDuration,
        uint256 pricePerBlock,
        address privateRenter
    );
    event Withdraw(address indexed tokenAddress, uint256 indexed tokenId);
    event Rent(
        address from,
        address indexed to,
        address indexed tokenAddress,
        uint256 indexed tokenId,
        address paymentTokenAddress,
        uint256 paymentTokenId,
        uint256 expiresAt
    );
    event RentEnds(address indexed tokenAddress, uint256 indexed tokenId);

    constructor(
        address _governance,
        address _operator,
        address payable _emergencyImplementation
    ) Security4(_governance, _operator, _emergencyImplementation) {}

    function getORentable(address wrapped_) external view returns (address) {
        return address(_orentables[wrapped_]);
    }

    function setORentable(address wrapped_, address oRentable_)
        external
        onlyGovernance
    {
        _orentables[wrapped_] = ORentable(oRentable_);
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

    function _getExistingORentable(address tokenAddress)
        internal
        view
        virtual
        returns (ORentable oRentable)
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
    ) internal virtual returns (ORentable oRentable) {
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
    ) internal returns (uint256 oRentableId) {
        ORentable oRentable = _getExistingORentable(tokenAddress);

        if (!skipTransfer) {
            IERC721(tokenAddress).transferFrom(to, address(this), tokenId);
        } else {
            require(
                IERC721(tokenAddress).ownerOf(tokenId) == address(this),
                "Token not deposited"
            );
        }

        oRentableId = oRentable.mint(to, tokenId);

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
        uint256 pricePerBlock,
        address privateRenter
    ) internal returns (uint256 oRentableId) {
        oRentableId = _deposit(tokenAddress, tokenId, to, skipTransfer);

        _createOrUpdateRentalConditions(
            tokenAddress,
            tokenId,
            paymentTokenAddress,
            paymentTokenId,
            maxTimeDuration,
            pricePerBlock,
            privateRenter
        );
    }

    function deposit(address tokenAddress, uint256 tokenId)
        external
        nonReentrant
        whenPausedthenProxy
        onlyAllowlisted
        returns (uint256)
    {
        return _deposit(tokenAddress, tokenId, msg.sender, false);
    }

    function depositAndList(
        address tokenAddress,
        uint256 tokenId,
        address paymentTokenAddress,
        uint256 paymentTokenId,
        uint256 maxTimeDuration,
        uint256 pricePerBlock,
        address privateRenter
    )
        external
        nonReentrant
        whenPausedthenProxy
        onlyAllowlisted
        returns (uint256)
    {
        return
            _depositAndList(
                tokenAddress,
                tokenId,
                msg.sender,
                false,
                paymentTokenAddress,
                paymentTokenId,
                maxTimeDuration,
                pricePerBlock,
                privateRenter
            );
    }

    function withdraw(address tokenAddress, uint256 tokenId)
        external
        nonReentrant
        whenPausedthenProxy
        onlyAllowlisted
    {
        address user = msg.sender;
        ORentable oRentable = _getExistingORentableCheckOwnership(
            tokenAddress,
            tokenId,
            user
        );

        require(
            !_expireRental(address(0), tokenAddress, tokenId, false),
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
        returns (RentalConditions memory)
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
        address tokenAddress,
        uint256 tokenId,
        address paymentTokenAddress,
        uint256 paymentTokenId,
        uint256 maxTimeDuration,
        uint256 pricePerBlock,
        address privateRenter
    ) internal {
        require(
            paymentTokenAllowlist[paymentTokenAddress] != NOT_ALLOWED_TOKEN,
            "Not supported payment token"
        );

        _rentalConditions[tokenAddress][tokenId] = RentalConditions({
            maxTimeDuration: maxTimeDuration,
            pricePerBlock: pricePerBlock,
            paymentTokenAddress: paymentTokenAddress,
            paymentTokenId: paymentTokenId,
            privateRenter: privateRenter
        });

        _postList(
            tokenAddress,
            tokenId,
            msg.sender,
            maxTimeDuration,
            pricePerBlock
        );

        emit UpdateRentalConditions(
            tokenAddress,
            tokenId,
            paymentTokenAddress,
            paymentTokenId,
            maxTimeDuration,
            pricePerBlock,
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
            if (block.number >= (_etas[tokenAddress][tokenId])) {
                address currentRentee = oTokenOwner == address(0)
                    ? ORentable(_orentables[tokenAddress]).ownerOf(tokenId)
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
        uint256 pricePerBlock,
        address privateRenter
    )
        external
        onlyOTokenOwner(tokenAddress, tokenId)
        whenPausedthenProxy
        onlyAllowlisted
    {
        _createOrUpdateRentalConditions(
            tokenAddress,
            tokenId,
            paymentTokenAddress,
            paymentTokenId,
            maxTimeDuration,
            pricePerBlock,
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
        onlyOTokenOwner(tokenAddress, tokenId)
        whenPausedthenProxy
        onlyAllowlisted
    {
        _deleteRentalConditions(tokenAddress, tokenId);
    }

    function rent(
        address tokenAddress,
        uint256 tokenId,
        uint256 duration
    ) external payable nonReentrant whenPausedthenProxy {
        ORentable oRentable = _getExistingORentable(tokenAddress);
        address payable rentee = payable(oRentable.ownerOf(tokenId));

        RentalConditions memory rcs = _rentalConditions[tokenAddress][tokenId];
        require(rcs.maxTimeDuration > 0, "Not available");

        require(
            !_expireRental(address(0), tokenAddress, tokenId, false),
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

        uint256 paymentQty = rcs.pricePerBlock * duration;

        // Fee calc
        uint256 feesForFeeCollector = fixedFee +
            (((paymentQty - fixedFee) * fee) / BASE_FEE);
        uint256 feesForRentee = paymentQty - feesForFeeCollector;

        uint256 eta = block.number + duration;
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
        whenPausedthenProxy
    {
        _expireRental(address(0), tokenAddress, tokenId, false);
    }

    function expireRentals(
        address[] calldata tokenAddresses,
        uint256[] calldata tokenIds
    ) external whenPausedthenProxy {
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            _expireRental(address(0), tokenAddresses[i], tokenIds[i], false);
        }
    }

    function afterWTokenTransfer(
        address tokenAddress,
        address from,
        address to,
        uint256 tokenId
    ) external whenPausedthenProxy {
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
    ) external whenPausedthenProxy {
        require(
            msg.sender == address(_orentables[tokenAddress]),
            "Only proper ORentables allowed"
        );

        bool rented = _expireRental(address(0), tokenAddress, tokenId, false);

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
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    )
        public
        virtual
        override
        nonReentrant
        whenPausedthenProxy
        returns (bytes4)
    {
        require(
            !allowlistEnabled || _isAllowlisted(operator),
            "User not allowed"
        );

        if (data.length == 0) {
            _deposit(msg.sender, tokenId, from, true);
        } else {
            RentalConditions memory rc = abi.decode(data, (RentalConditions));

            _depositAndList(
                msg.sender,
                tokenId,
                from,
                true,
                rc.paymentTokenAddress,
                rc.paymentTokenId,
                rc.maxTimeDuration,
                rc.pricePerBlock,
                rc.privateRenter
            );
        }

        return this.onERC721Received.selector;
    }
}
