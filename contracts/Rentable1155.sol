// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@emilianobonassi-security/contracts/Security4.sol";
import "./ORentable1155.sol";
import "./WRentable1155.sol";
import "./IRentable1155.sol";
import "./IORentable1155Hooks.sol";
import "./IWRentable1155Hooks.sol";

contract Rentable1155 is
    IRentable1155,
    IORentable1155Hooks,
    IWRentable1155Hooks,
    Security4,
    ERC1155Receiver,
    ReentrancyGuard
{
    using Address for address;
    using SafeERC20 for IERC20;

    mapping(address => mapping(uint256 => RentalConditions))
        internal _rentalConditions;

    mapping(address => mapping(uint256 => Rental)) public _rentals;
    mapping(address => mapping(uint256 => uint256[]))
        public currentRentalIdsByOTokenId;
    mapping(address => WRentable1155) public wrentables;

    mapping(address => uint256) internal wTokenIdCounter;
    mapping(address => uint256) internal oTokenIdCounter;
    mapping(address => mapping(uint256 => uint256)) public oTokenIds2tokenIds;
    mapping(address => mapping(address => mapping(uint256 => uint256)))
        public user1155Balances; //for 1155 abstraction
    mapping(address => mapping(address => mapping(uint256 => uint256)))
        public oTokenUser1155Balances; //for internal checks
    mapping(address => ORentable1155) public orentables;

    mapping(address => uint8) public paymentTokenAllowlist;

    uint8 private constant NOT_ALLOWED_TOKEN = 0;
    uint8 private constant ERC20_TOKEN = 1;
    uint8 private constant ERC1155_TOKEN = 2;

    uint16 public constant BASE_FEE = 10000;
    uint256 public fixedFee;
    uint16 public fee;

    uint256 private constant DEPOSIT_BARRIER_OFF = 1;
    uint256 private constant DEPOSIT_BARRIER_ON = 2;
    uint256 private _depositBarrier = DEPOSIT_BARRIER_OFF;

    address payable public feeCollector;

    event Deposit(
        address indexed who,
        address indexed tokenAddress,
        uint256 indexed tokenId,
        uint256 amount,
        uint256 oTokenId
    );

    event UpdateRentalConditions(
        address indexed oTokenAddress,
        uint256 indexed oTokenId,
        address paymentTokenAddress,
        uint256 paymentTokenId,
        uint256 maxTimeDuration,
        uint256 pricePerBlock,
        address privateRenter
    );

    event Withdraw(
        address indexed who,
        address indexed tokenAddress,
        uint256 indexed tokenId,
        uint256 oTokenId,
        uint256 amount
    );

    event Rent(
        address from,
        address indexed to,
        address indexed tokenAddress,
        uint256 indexed oTokenId,
        uint256 wTokenId
    );

    event RentEnds(address indexed wTokenAddress, uint256 indexed wTokenId);

    constructor(
        address _governance,
        address _operator,
        address payable _emergencyImplementation
    ) Security4(_governance, _operator, _emergencyImplementation) {}

    function setORentable(address wrapped_, address oRentable_)
        external
        onlyGovernance
    {
        orentables[wrapped_] = ORentable1155(oRentable_);
    }

    function setWRentable(address wrapped_, address wRentable_)
        external
        onlyGovernance
    {
        wrentables[wrapped_] = WRentable1155(wRentable_);
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

    function _getExistingORentable1155(address tokenAddress)
        internal
        view
        virtual
        returns (ORentable1155 oRentable)
    {
        oRentable = orentables[tokenAddress];
        require(
            address(oRentable) != address(0),
            "Token currently not supported"
        );
    }

    function _getExistingORentableCheckOwnership(
        address tokenAddress,
        uint256 oTokenId,
        address user
    ) internal virtual returns (ORentable1155 oRentable) {
        oRentable = _getExistingORentable1155(tokenAddress);

        require(oRentable.ownerOf(oTokenId) == user, "The token must be yours");
    }

    function _deposit(
        address tokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 oTokenId,
        address to,
        bool skipTransfer
    ) internal returns (address oRentableAddress, uint256 oRentableId) {
        _depositBarrier = DEPOSIT_BARRIER_ON;
        require(amount > 0, "Cannot deposit 0");

        ORentable1155 oRentable = _getExistingORentable1155(tokenAddress);

        if (!skipTransfer) {
            IERC1155(tokenAddress).safeTransferFrom(
                to,
                address(this),
                tokenId,
                amount,
                ""
            );
        }

        if (oTokenId == 0) {
            oRentableId = ++oTokenIdCounter[address(oRentable)];
            oTokenIds2tokenIds[address(oRentable)][oRentableId] = tokenId;
            oRentable.mint(to, oRentableId);
        } else {
            require(
                oRentable.ownerOf(oTokenId) == to,
                "Otoken must belong to the user"
            );
            require(
                oTokenIds2tokenIds[address(oRentable)][oTokenId] == tokenId,
                "Cannot deposit different tokenId"
            );
            oRentableId = oTokenId;
        }

        user1155Balances[tokenAddress][to][tokenId] += amount;
        oTokenUser1155Balances[tokenAddress][to][oRentableId] += amount;

        emit Deposit(to, tokenAddress, tokenId, amount, oRentableId);

        _depositBarrier = DEPOSIT_BARRIER_OFF;
        return (address(oRentable), oRentableId);
    }

    function deposit(
        address tokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 oTokenId
    )
        external
        nonReentrant
        whenPausedthenProxy
        onlyAllowlisted
        returns (uint256 oRentableId)
    {
        (, oRentableId) = _deposit(
            tokenAddress,
            tokenId,
            amount,
            oTokenId,
            _msgSender(),
            false
        );

        return oRentableId;
    }

    function _depositAndList(
        address tokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 oTokenId,
        address to,
        RentalConditions memory rentalCondition
    ) internal returns (uint256 oRentableId) {
        return
            _depositAndList(
                tokenAddress,
                tokenId,
                amount,
                oTokenId,
                to,
                true,
                rentalCondition.paymentTokenAddress,
                rentalCondition.paymentTokenId,
                rentalCondition.maxTimeDuration,
                rentalCondition.pricePerBlock,
                rentalCondition.privateRenter
            );
    }

    function _depositAndList(
        address tokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 oTokenId,
        address to,
        bool skipTransfer,
        address paymentTokenAddress,
        uint256 paymentTokenId,
        uint256 maxTimeDuration,
        uint256 pricePerBlock,
        address privateRenter
    ) internal returns (uint256 oRentableId) {
        address oRentableAddress;
        (oRentableAddress, oRentableId) = _deposit(
            tokenAddress,
            tokenId,
            amount,
            oTokenId,
            to,
            skipTransfer
        );

        _createOrUpdateRentalConditions(
            oRentableAddress,
            oRentableId,
            paymentTokenAddress,
            paymentTokenId,
            maxTimeDuration,
            pricePerBlock,
            privateRenter
        );
    }

    function depositAndList(
        address tokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 oTokenId,
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
                amount,
                oTokenId,
                msg.sender,
                false,
                paymentTokenAddress,
                paymentTokenId,
                maxTimeDuration,
                pricePerBlock,
                privateRenter
            );
    }

    function withdraw(
        address tokenAddress,
        uint256 oTokenId,
        uint256 amount
    ) external nonReentrant whenPausedthenProxy onlyAllowlisted {
        require(amount > 0, "Cannot withdraw 0");

        ORentable1155 oRentable = _getExistingORentableCheckOwnership(
            tokenAddress,
            oTokenId,
            msg.sender
        );

        uint256 tokenId = oTokenIds2tokenIds[address(oRentable)][oTokenId];

        uint256 currentlyRented = _expireRentals(
            address(wrentables[tokenAddress]),
            tokenAddress,
            oTokenId
        );

        require(
            amount <=
                oTokenUser1155Balances[tokenAddress][msg.sender][oTokenId] -
                    currentlyRented,
            "Amount required not available, busy on rental"
        );

        user1155Balances[tokenAddress][msg.sender][tokenId] -= amount;
        uint256 oBalance = (oTokenUser1155Balances[tokenAddress][msg.sender][
            oTokenId
        ] -= amount);

        if (oBalance == 0) {
            delete _rentalConditions[tokenAddress][oTokenId];
            delete oTokenIds2tokenIds[address(oRentable)][oTokenId];
            oRentable.burn(oTokenId);
        }

        IERC1155(tokenAddress).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId,
            amount,
            ""
        );

        emit Withdraw(msg.sender, tokenAddress, tokenId, oTokenId, amount);
    }

    function rentalConditions(address tokenAddress, uint256 oTokenId)
        external
        view
        returns (RentalConditions memory)
    {
        return _rentalConditions[address(orentables[tokenAddress])][oTokenId];
    }

    function _createOrUpdateRentalConditions(
        address oTokenAddress,
        uint256 oTokenId,
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

        _rentalConditions[oTokenAddress][oTokenId] = RentalConditions({
            maxTimeDuration: maxTimeDuration,
            pricePerBlock: pricePerBlock,
            paymentTokenAddress: paymentTokenAddress,
            paymentTokenId: paymentTokenId,
            privateRenter: privateRenter
        });

        emit UpdateRentalConditions(
            oTokenAddress,
            oTokenId,
            paymentTokenAddress,
            paymentTokenId,
            maxTimeDuration,
            pricePerBlock,
            privateRenter
        );
    }

    function createOrUpdateRentalConditions(
        address tokenAddress,
        uint256 oTokenId,
        address paymentTokenAddress,
        uint256 paymentTokenId,
        uint256 maxTimeDuration,
        uint256 pricePerBlock,
        address privateRenter
    ) external whenPausedthenProxy onlyAllowlisted {
        address oTokenAddress = address(
            _getExistingORentableCheckOwnership(
                tokenAddress,
                oTokenId,
                msg.sender
            )
        );

        _createOrUpdateRentalConditions(
            oTokenAddress,
            oTokenId,
            paymentTokenAddress,
            paymentTokenId,
            maxTimeDuration,
            pricePerBlock,
            privateRenter
        );
    }

    function deleteRentalConditions(address tokenAddress, uint256 oTokenId)
        external
        whenPausedthenProxy
        onlyAllowlisted
    {
        address oTokenAddress = address(
            _getExistingORentableCheckOwnership(
                tokenAddress,
                oTokenId,
                msg.sender
            )
        );

        delete _rentalConditions[oTokenAddress][oTokenId];
    }

    function afterOToken1155Transfer(
        address tokenAddress,
        address from,
        address to,
        uint256 oTokenId
    ) external virtual override whenPausedthenProxy {
        address oRentableAddress = address(orentables[tokenAddress]);
        require(
            msg.sender == oRentableAddress,
            "Only proper ORentables allowed"
        );

        //TODO: check current leases
        bool rented = false;

        // Change internal balances
        uint256 oBalance = oTokenUser1155Balances[tokenAddress][from][oTokenId];
        oTokenUser1155Balances[tokenAddress][from][oTokenId] -= oBalance;
        oTokenUser1155Balances[tokenAddress][to][oTokenId] += oBalance;

        uint256 tokenId = oTokenIds2tokenIds[oRentableAddress][oTokenId];
        user1155Balances[tokenAddress][from][tokenId] -= oBalance;
        user1155Balances[tokenAddress][to][tokenId] += oBalance;
    }

    function afterWToken1155Transfer(
        address tokenAddress,
        address from,
        address to,
        uint256 wTokenId
    ) external virtual override whenPausedthenProxy {}

    function expireRentals(
        address[] calldata wRentables,
        address[] calldata tokenAddresses,
        uint256[] calldata oTokenIds
    ) external virtual {
        for (uint256 i = 0; i < oTokenIds.length; ) {
            address wRentable = wRentables[i];
            address tokenAddress = tokenAddresses[i];
            uint256 oTokenId = oTokenIds[i];

            uint256[] storage rentalIds = currentRentalIdsByOTokenId[
                tokenAddress
            ][oTokenId];

            for (uint256 j = 0; j < rentalIds.length; ) {
                uint256 rentalId = rentalIds[j];
                Rental memory rental = (_rentals[wRentable][rentalId]);
                if (block.number >= rental.eta) {
                    WRentable1155(wRentable).burn(rentalId);
                    rentalIds[j] = rentalIds[rentalIds.length - 1];
                    rentalIds.pop();
                    delete (_rentals[wRentable][rentalId]);
                    emit RentEnds(wRentable, rentalId);
                }

                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    function _expireRentals(
        address wRentable,
        address tokenAddress,
        uint256 oTokenId
    ) internal virtual returns (uint256 currentlyRented) {
        uint256[] storage rentalIds = currentRentalIdsByOTokenId[tokenAddress][
            oTokenId
        ];

        for (uint256 i = 0; i < rentalIds.length; ) {
            uint256 rentalId = rentalIds[i];
            Rental memory rental = (_rentals[wRentable][rentalId]);
            if (block.number >= rental.eta) {
                WRentable1155(wRentable).burn(rentalId);
                rentalIds[i] = rentalIds[rentalIds.length - 1];
                rentalIds.pop();
                delete (_rentals[wRentable][rentalId]);
                emit RentEnds(wRentable, rentalId);
            } else {
                currentlyRented += rental.amount;
            }

            unchecked {
                ++i;
            }
        }

        return currentlyRented;
    }

    function rentals(address wTokenAddress, uint256 wTokenId)
        external
        view
        virtual
        override
        returns (Rental memory)
    {
        return _rentals[wTokenAddress][wTokenId];
    }

    function rent(
        address tokenAddress,
        uint256 oTokenId,
        uint256 duration,
        uint256 amount
    ) external payable nonReentrant whenPausedthenProxy {
        require(amount > 0, "Cannot rent 0");

        ORentable1155 oRentable = _getExistingORentable1155(tokenAddress);
        address payable rentee = payable(oRentable.ownerOf(oTokenId));

        RentalConditions memory rentalCondition = _rentalConditions[
            address(oRentable)
        ][oTokenId];
        require(rentalCondition.maxTimeDuration > 0, "Not available");

        WRentable1155 wRentable = wrentables[tokenAddress];

        uint256 currentlyRented = _expireRentals(
            address(wRentable),
            tokenAddress,
            oTokenId
        );

        require(
            duration <= rentalCondition.maxTimeDuration,
            "Duration greater than conditions"
        );

        require(
            amount <=
                oTokenUser1155Balances[tokenAddress][rentee][oTokenId] -
                    currentlyRented,
            "Amount required not available"
        );

        require(
            rentalCondition.privateRenter == address(0) ||
                rentalCondition.privateRenter == msg.sender,
            "Rental reserved for another user"
        );

        uint256 paymentQty = rentalCondition.pricePerBlock * duration;

        // Fee calc
        uint256 feesForFeeCollector = fixedFee +
            (((paymentQty - fixedFee) * fee) / BASE_FEE);
        uint256 feesForRentee = paymentQty - feesForFeeCollector;

        uint256 rentId = ++wTokenIdCounter[address(wRentable)];

        _rentals[address(wRentable)][rentId] = Rental({
            eta: block.number + duration,
            amount: amount
        });

        (currentRentalIdsByOTokenId[tokenAddress][oTokenId]).push(rentId);

        wRentable.mint(msg.sender, rentId);

        if (rentalCondition.paymentTokenAddress == address(0)) {
            require(msg.value >= paymentQty, "Not enough funds");
            if (feesForFeeCollector > 0) {
                Address.sendValue(feeCollector, feesForFeeCollector);
            }

            Address.sendValue(rentee, feesForRentee);

            if (msg.value > paymentQty) {
                Address.sendValue(payable(msg.sender), msg.value - paymentQty);
            }
        } else if (
            paymentTokenAllowlist[rentalCondition.paymentTokenAddress] ==
            ERC20_TOKEN
        ) {
            if (feesForFeeCollector > 0) {
                IERC20(rentalCondition.paymentTokenAddress).safeTransferFrom(
                    msg.sender,
                    feeCollector,
                    feesForFeeCollector
                );
            }

            IERC20(rentalCondition.paymentTokenAddress).safeTransferFrom(
                msg.sender,
                rentee,
                feesForRentee
            );
        } else {
            if (feesForFeeCollector > 0) {
                IERC1155(rentalCondition.paymentTokenAddress).safeTransferFrom(
                    msg.sender,
                    feeCollector,
                    rentalCondition.paymentTokenId,
                    feesForFeeCollector,
                    ""
                );
            }

            IERC1155(rentalCondition.paymentTokenAddress).safeTransferFrom(
                msg.sender,
                rentee,
                rentalCondition.paymentTokenId,
                feesForRentee,
                ""
            );
        }

        emit Rent(rentee, msg.sender, tokenAddress, oTokenId, rentId);
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external virtual override returns (bytes4) {
        if (
            _depositBarrier == DEPOSIT_BARRIER_ON ||
            paymentTokenAllowlist[msg.sender] == ERC1155_TOKEN
        ) {
            return this.onERC1155Received.selector;
        }
        //We can call ourselves (during rent on pull 1155 for payment)
        require(
            !allowlistEnabled || _isAllowlisted(operator),
            "User not allowed"
        );

        //Check msg.sender is a payment token or a token we support
        if (data.length == 192) {
            (uint256 oTokenId, RentalConditions memory rcs) = abi.decode(
                data,
                (uint256, RentalConditions)
            );

            _depositAndList(msg.sender, id, value, oTokenId, from, rcs);
        } else {
            _deposit(msg.sender, id, value, 0, from, true);
        }

        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        revert("Not supported");
    }
}
