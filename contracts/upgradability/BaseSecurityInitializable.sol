// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 *  base security:
 *  1. establish simple two-roles contract, governance and operator.
 *  Operator can be changed only by governance. Governance update needs acceptance.
 *  2. can be paused by operator or governance via SCRAM()
 *  3. only governance can recover from pause via unpause
 *  4. only governance can withdraw in emergency
 *  5. only governance execute any tx in emergency
 */

contract BaseSecurityInitializable is Initializable, Pausable {
    using SafeERC20 for IERC20;
    address constant ETHER = address(0);

    address public pendingGovernance;
    address public governance;
    address public operator;

    event LogWithdraw(
        address indexed _from,
        address indexed _assetAddress,
        uint256 indexed tokenId,
        uint256 amount
    );

    modifier onlyGovernance() {
        require(msg.sender == governance, "Only Governance");
        _;
    }

    modifier onlyOperatorOrGovernance() {
        require(
            msg.sender == operator || msg.sender == governance,
            "Only Operator or Governance"
        );
        _;
    }

    function __BaseSecurityInitializable_init(
        address _governance,
        address _operator
    ) internal onlyInitializing {
        governance = _governance;
        operator = _operator;
    }

    /**
     * @dev Set operator
     * @param _operator operator address.
     */
    function setOperator(address _operator) public virtual onlyGovernance {
        operator = _operator;
    }

    /**
     * @dev Set new governance
     * @param _governance governance address.
     */
    function setGovernance(address _governance) public virtual onlyGovernance {
        pendingGovernance = _governance;
    }

    /**
     * @dev Accept proposed governance
     */
    function acceptGovernance() public virtual {
        require(msg.sender == pendingGovernance, "Only Proposed Governance");

        governance = pendingGovernance;
        pendingGovernance = address(0);
    }

    /**
     * @dev Pause all operations
     */
    function SCRAM() public onlyOperatorOrGovernance {
        _pause();
    }

    /**
     * @dev Returns to normal state.
     */
    function unpause() public onlyGovernance {
        _unpause();
    }

    /**
     * @dev Withdraw asset ERC20 or ETH
     * @param _assetAddress Asset to be withdrawn.
     */
    function _withdrawERC20ETH(address _assetAddress) internal virtual {
        uint256 assetBalance;
        if (_assetAddress == ETHER) {
            address self = address(this); // workaround for a possible solidity bug
            assetBalance = self.balance;
            payable(msg.sender).transfer(assetBalance);
        } else {
            assetBalance = IERC20(_assetAddress).balanceOf(address(this));
            IERC20(_assetAddress).safeTransfer(msg.sender, assetBalance);
        }
        emit LogWithdraw(msg.sender, _assetAddress, 0, assetBalance);
    }

    /**
     * @dev Withdraw asset ERC721
     * @param _assetAddress token address.
     * @param _tokenId token id.
     * @param _notSafe use safeTransfer.
     */
    function _withdrawERC721(
        address _assetAddress,
        uint256 _tokenId,
        bool _notSafe
    ) internal virtual {
        if (_notSafe) {
            IERC721(_assetAddress).transferFrom(
                address(this),
                msg.sender,
                _tokenId
            );
        } else {
            IERC721(_assetAddress).safeTransferFrom(
                address(this),
                msg.sender,
                _tokenId
            );
        }
        emit LogWithdraw(msg.sender, _assetAddress, _tokenId, 1);
    }

    /**
     * @dev Batch withdraw asset ERC721
     * @param _assetAddress token address.
     * @param _tokenIds token ids.
     */
    function _batchWithdrawERC721(
        address _assetAddress,
        uint256[] calldata _tokenIds,
        bool _notSafe
    ) internal virtual {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            _withdrawERC721(_assetAddress, _tokenIds[i], _notSafe);
        }
    }

    /**
     * @dev Withdraw asset ERC1155
     * @param _assetAddress token address.
     * @param _tokenId token id.
     */
    function _withdrawERC1155(address _assetAddress, uint256 _tokenId)
        internal
        virtual
    {
        uint256 assetBalance = IERC1155(_assetAddress).balanceOf(
            address(this),
            _tokenId
        );
        IERC1155(_assetAddress).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId,
            assetBalance,
            ""
        );
        emit LogWithdraw(msg.sender, _assetAddress, _tokenId, assetBalance);
    }

    /**
     * @dev Batch withdraw asset ERC1155
     * @param _assetAddress token address.
     * @param _tokenIds token ids.
     */
    function _batchWithdrawERC1155(
        address _assetAddress,
        uint256[] calldata _tokenIds
    ) internal virtual {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            _withdrawERC1155(_assetAddress, _tokenIds[i]);
        }
    }

    function emergencyWithdrawERC20ETH(address _assetAddress)
        public
        virtual
        onlyGovernance
        whenPaused
    {
        _withdrawERC20ETH(_assetAddress);
    }

    function emergencyWithdrawERC721(
        address _assetAddress,
        uint256 _tokenId,
        bool _notSafe
    ) public virtual onlyGovernance whenPaused {
        _withdrawERC721(_assetAddress, _tokenId, _notSafe);
    }

    function emergencyBatchWithdrawERC721(
        address _assetAddress,
        uint256[] calldata _tokenIds,
        bool _notSafe
    ) public virtual onlyGovernance whenPaused {
        _batchWithdrawERC721(_assetAddress, _tokenIds, _notSafe);
    }

    function emergencyWithdrawERC1155(address _assetAddress, uint256 _tokenId)
        public
        virtual
        onlyGovernance
        whenPaused
    {
        _withdrawERC1155(_assetAddress, _tokenId);
    }

    function emergencyBatchWithdrawERC1155(
        address _assetAddress,
        uint256[] calldata _tokenIds
    ) public virtual onlyGovernance whenPaused {
        _batchWithdrawERC1155(_assetAddress, _tokenIds);
    }

    /**
     * @dev Execute any tx in emergency (only governance)
     */
    function emergencyExecute(
        address to,
        uint256 value,
        bytes memory data,
        bool isDelegateCall,
        uint256 txGas
    ) public payable virtual whenPaused onlyGovernance {
        bool success;

        if (isDelegateCall) {
            // solhint-disable-next-line no-inline-assembly
            assembly {
                success := delegatecall(
                    txGas,
                    to,
                    add(data, 0x20),
                    mload(data),
                    0,
                    0
                )
            }
        } else {
            // solhint-disable-next-line no-inline-assembly
            assembly {
                success := call(
                    txGas,
                    to,
                    value,
                    add(data, 0x20),
                    mload(data),
                    0,
                    0
                )
            }
        }

        require(success, "failed execution");
    }

    // Reserved storage space to allow for layout changes in the future.
    uint256[50] private ______gap;
}
