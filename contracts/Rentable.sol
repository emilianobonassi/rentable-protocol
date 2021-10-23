// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ORentable.sol";
import "./YRentable.sol";
import "./WRentable.sol";

contract Rentable is Ownable, IERC721Receiver {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct LeaseConditions {
        uint256 maxTimeDuration;
        uint256 pricePerBlock;
        address paymentTokenAddress;
        uint256 fixedFee;
        uint256 fee;
    }

    struct Lease {
        address paymentTokenAddress;
        uint256 eta;
        uint256 qtyToPullRemaining;
        uint256 feesToPullRemaining;
        uint256 lastUpdated;
        address tokenAddress;
        uint256 tokenId;
        address from;
        address to;
    }

    address internal _yToken;

    mapping (address => mapping(uint256 => LeaseConditions)) internal _leasesConditions;

    mapping (uint256 => Lease) internal _leases;

    mapping (address => mapping(uint256 => uint256)) internal _currentLeases;

    mapping (address => address) internal _wrentables;
    mapping (address => ORentable) internal _orentables;

    uint256 constant public BASE_FEE = 10000;
    uint256 internal _fixedFee;
    uint256 internal _fee;

    address payable _feeCollector;

    event Deposit(address indexed who, address indexed tokenAddress, uint256 indexed tokenId);
    event UpdateLeaseConditions(address indexed tokenAddress, uint256 indexed tokenId, address paymentTokenAddress, uint256 maxTimeDuration, uint256 pricePerBlock);
    event Withdraw(address indexed who, address indexed tokenAddress, uint256 indexed tokenId);
    event Rent(address from, address indexed to, address indexed tokenAddress, uint256 indexed tokenId, uint256 yTokenId);
    event Claim(address indexed who, address indexed tokenAddress, uint256 indexed tokenId, address paymentTokenAddress, uint256 qty, uint256 yTokenId);
    event RentEnds(address from, address indexed to, address indexed tokenAddress, uint256 indexed tokenId, uint256 yTokenId);

    constructor() {}

    function setORentable(address wrapped_, address oRentable_)
        external
        onlyOwner
    {
        _orentables[wrapped_] = ORentable(oRentable_);
    }

    function setYToken(address yToken_)
        external
        onlyOwner
    {
        _yToken = yToken_;
    }

    function setWRentable(address wrapped_, address rentable_)
        external
        onlyOwner
    {
        _wrentables[wrapped_] = rentable_;
    }

    function getFixedFee() external view returns (uint256) {
        return _fixedFee;
    }

    function setFixedFee(uint256 fixedFee) external onlyOwner {
        _fixedFee = fixedFee;
    }

    function getFee() external view returns (uint256) {
        return _fee;
    }

    function setFee(uint256 fee) external onlyOwner {
        _fee = fee;
    }

    function getFeeCollector() external view returns (address) {
        return _feeCollector;
    }

    function setFeeCollector(address payable feeCollector) external onlyOwner {
        _feeCollector = feeCollector;
    }

    function _getExistingORentable(address tokenAddress) internal virtual view returns (ORentable oRentable) {
        oRentable = _orentables[tokenAddress];
        require(address(oRentable) != address(0), "Token currently not supported");
    }

    function _getExistingORentableCheckOwnership(address tokenAddress, uint256 tokenId, address user) internal virtual returns (ORentable oRentable) {
        oRentable = _getExistingORentable(tokenAddress);

        require(oRentable.ownerOf(tokenId) == user, 'The token must be yours');
    }

    modifier onlyOTokenOwner(address tokenAddress, uint256 tokenId) {
        _getExistingORentableCheckOwnership(tokenAddress, tokenId, _msgSender());
        _;
    }

    function _deposit(address tokenAddress, uint256 tokenId, address to, bool skipTransfer)
        internal
        returns (uint256 oRentableId) {
        ORentable oRentable = _getExistingORentable(tokenAddress);

        if (!skipTransfer) {
            IERC721(tokenAddress).transferFrom(to, address(this), tokenId);
        } else {
            require(IERC721(tokenAddress).ownerOf(tokenId) == address(this), "Token not deposited");
        }

        oRentableId = oRentable.mint(to, tokenId);

        emit Deposit(to, tokenAddress, tokenId);
    }

    function _depositAndList(address tokenAddress, uint256 tokenId, address to, bool skipTransfer, address paymentTokenAddress, uint256 maxTimeDuration, uint256 pricePerBlock) internal returns (uint256 oRentableId) {
        oRentableId = _deposit(tokenAddress, tokenId, to, skipTransfer);

        _createOrUpdateLeaseConditions(tokenAddress, tokenId, paymentTokenAddress, maxTimeDuration, pricePerBlock);
    }

    function deposit(address tokenAddress, uint256 tokenId)
        external
        returns (uint256) {
        return _deposit(tokenAddress, tokenId, _msgSender(), false);
    }

    function depositAndList(address tokenAddress, uint256 tokenId, address paymentTokenAddress, uint256 maxTimeDuration, uint256 pricePerBlock) external returns (uint256) {
        return _depositAndList(tokenAddress, tokenId, _msgSender(), false, paymentTokenAddress, maxTimeDuration, pricePerBlock);
    }

    function withdraw(address tokenAddress, uint256 tokenId)
        external {
        address user = _msgSender();
        ORentable oRentable = _getExistingORentableCheckOwnership(tokenAddress, tokenId, user);

        uint256 leaseId = _currentLeases[tokenAddress][tokenId];
        if (leaseId != 0) {
            Lease memory currentLease = _leases[leaseId];
            require(block.number > currentLease.eta, "Current lease still pending");
        }

        IERC721(tokenAddress).transferFrom(address(this), user, tokenId);

        delete _leasesConditions[tokenAddress][tokenId];
        
        oRentable.burn(tokenId);

        emit Withdraw(user, tokenAddress, tokenId);
    }

    function leasesConditions(address tokenAddress, uint256 tokenId) view external returns (LeaseConditions memory) {
        return _leasesConditions[tokenAddress][tokenId];
    }

    function currentLeases(address tokenAddress, uint256 tokenId) view external returns (Lease memory) {
        return _leases[_currentLeases[tokenAddress][tokenId]];
    }

    function _createOrUpdateLeaseConditions(address tokenAddress, uint256 tokenId, address paymentTokenAddress, uint256 maxTimeDuration, uint256 pricePerBlock) internal {
        LeaseConditions storage lease = _leasesConditions[tokenAddress][tokenId];

        lease.maxTimeDuration = maxTimeDuration;
        lease.pricePerBlock = pricePerBlock;
        lease.paymentTokenAddress = paymentTokenAddress;
        lease.fixedFee = _fixedFee;
        lease.fee = _fee;

        emit UpdateLeaseConditions(tokenAddress, tokenId, paymentTokenAddress, maxTimeDuration, pricePerBlock);
    }

    function createOrUpdateLeaseConditions(address tokenAddress, uint256 tokenId, address paymentTokenAddress, uint256 maxTimeDuration, uint256 pricePerBlock)
        onlyOTokenOwner(tokenAddress, tokenId)
        external {
        _createOrUpdateLeaseConditions(tokenAddress, tokenId, paymentTokenAddress, maxTimeDuration, pricePerBlock);
    }

    function deleteLeaseConditions(address tokenAddress, uint256 tokenId)
        onlyOTokenOwner(tokenAddress, tokenId)
        external {
        delete _leasesConditions[tokenAddress][tokenId];
    }

    function createLease(address tokenAddress, uint256 tokenId, uint256 duration)
        external
        payable
    {
        ORentable oRentable = _getExistingORentable(tokenAddress);
        address from = oRentable.ownerOf(tokenId);

        LeaseConditions memory leaseCondition = _leasesConditions[tokenAddress][tokenId];
        require(leaseCondition.maxTimeDuration > 0, "Not available");
        
        uint256 leaseId = _currentLeases[tokenAddress][tokenId];

        if (leaseId != 0) {
            Lease memory currentLease = _leases[leaseId];
            require(block.number > currentLease.eta, "Current lease still pending");
            if (WRentable(_wrentables[tokenAddress]).exists(tokenId)) {
                WRentable(_wrentables[tokenAddress]).burn(tokenId);
                emit RentEnds(currentLease.from, currentLease.to, tokenAddress, tokenId, leaseId);
            }
        }

        require(duration <= leaseCondition.maxTimeDuration, "Duration greater than conditions");

        address user = _msgSender();
        uint256 paymentQty = leaseCondition.pricePerBlock.mul(duration);

        // Fee calc
        uint256 qtyToPullRemaining = paymentQty.sub(leaseCondition.fixedFee);
        uint256 feesToPullRemaining = qtyToPullRemaining.mul(leaseCondition.fee).div(BASE_FEE);
        qtyToPullRemaining = qtyToPullRemaining.sub(feesToPullRemaining);

        if(leaseCondition.paymentTokenAddress == address(0)) {
            require(msg.value >= paymentQty, "Not enough funds");
            if (msg.value > paymentQty) {
                payable(user).transfer(msg.value.sub(paymentQty));
            }
            
            if(leaseCondition.fixedFee > 0) {
                _feeCollector.transfer(leaseCondition.fixedFee);
            }
        } else {
            IERC20(leaseCondition.paymentTokenAddress).safeTransferFrom(user, address(this), paymentQty);
            if (msg.value > 0) {
                payable(user).transfer(msg.value);
            }

            if(leaseCondition.fixedFee > 0) {
                IERC20(leaseCondition.paymentTokenAddress).safeTransfer(_feeCollector, leaseCondition.fixedFee);
            }
        }
        
        leaseId = YRentable(_yToken).mint(from);

        Lease storage lease = _leases[leaseId];
        lease.eta = block.number.add(duration);
        lease.qtyToPullRemaining = qtyToPullRemaining;
        lease.feesToPullRemaining = feesToPullRemaining;
        lease.lastUpdated = block.number;
        lease.tokenAddress = tokenAddress;
        lease.tokenId = tokenId;
        lease.from = from;
        lease.to = user;
        lease.paymentTokenAddress = leaseCondition.paymentTokenAddress;

        _currentLeases[tokenAddress][tokenId] = leaseId;

        WRentable(_wrentables[tokenAddress]).mint(user, tokenId);

        emit Rent(from, user, tokenAddress, tokenId, leaseId);
    }

    function redeemLease(uint256 leaseId) external {
        address user = _msgSender();
        require(IERC721(_yToken).ownerOf(leaseId) == user, 'You should own respective yRentable');
        
        Lease storage lease2redeem = _leases[leaseId];

        // Calculate linearly the amount remaining
        require(lease2redeem.qtyToPullRemaining > 0, 'Nothing to redeem for the lease');

        uint256 amount2Redeem = 0;
        uint256 fees2Redeem = 0;
        if (block.number >= lease2redeem.eta) {
            amount2Redeem = lease2redeem.qtyToPullRemaining;
            fees2Redeem = lease2redeem.feesToPullRemaining;

            if (WRentable(_wrentables[lease2redeem.tokenAddress]).exists(lease2redeem.tokenId)) {
                WRentable(_wrentables[lease2redeem.tokenAddress]).burn(lease2redeem.tokenId);
                emit RentEnds(lease2redeem.from, lease2redeem.to, lease2redeem.tokenAddress, lease2redeem.tokenId, leaseId);
            }
        } else {
            amount2Redeem = lease2redeem.qtyToPullRemaining
            .mul(
                block.number.sub(lease2redeem.lastUpdated)
            )
            .div(
                lease2redeem.eta.sub(lease2redeem.lastUpdated)
            );

            if (lease2redeem.feesToPullRemaining > 0) {
                fees2Redeem = lease2redeem.feesToPullRemaining
                .mul(
                    block.number.sub(lease2redeem.lastUpdated)
                )
                .div(
                    lease2redeem.eta.sub(lease2redeem.lastUpdated)
                );
            }
        }

        // approx safety check
        if (amount2Redeem > lease2redeem.qtyToPullRemaining) {
            amount2Redeem = lease2redeem.qtyToPullRemaining;
        }

        if (fees2Redeem > lease2redeem.feesToPullRemaining) {
            fees2Redeem = lease2redeem.feesToPullRemaining;
        }

        lease2redeem.qtyToPullRemaining = lease2redeem.qtyToPullRemaining.sub(amount2Redeem);
        if (fees2Redeem > 0) {
            lease2redeem.feesToPullRemaining = lease2redeem.feesToPullRemaining.sub(fees2Redeem);
        }
        lease2redeem.lastUpdated = block.number;

        if (lease2redeem.paymentTokenAddress == address(0)) {
            payable(user).transfer(amount2Redeem);
            if (fees2Redeem > 0) {
                payable(_feeCollector).transfer(fees2Redeem);
            }
        } else {
            IERC20(lease2redeem.paymentTokenAddress).safeTransfer(user, amount2Redeem);
            if (fees2Redeem > 0) {
                IERC20(lease2redeem.paymentTokenAddress).safeTransfer(_feeCollector, fees2Redeem);
            }
        }

        emit Claim(user, lease2redeem.tokenAddress, lease2redeem.tokenId, lease2redeem.paymentTokenAddress, amount2Redeem, leaseId);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) public virtual override returns (bytes4) {

        if (data.length == 0) {
            _deposit(_msgSender(), tokenId, from, true);
        } else {
            (
                address paymentTokenAddress,
                uint256 maxTimeDuration,
                uint256 pricePerBlock
            ) = abi.decode(data, (address, uint256, uint256));

            _depositAndList(_msgSender(), tokenId, from, true, paymentTokenAddress, maxTimeDuration, pricePerBlock);
        }

        return this.onERC721Received.selector;
    }
}