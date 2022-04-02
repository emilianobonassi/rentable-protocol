// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

// Inheritance

import {PausableUpgradeable} from "@openzeppelin-upgradable/contracts/security/PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin-upgradable/contracts/proxy/utils/Initializable.sol";

// Libraries
import {SafeERC20Upgradeable} from "@openzeppelin-upgradable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

// References
import {IERC20Upgradeable} from "@openzeppelin-upgradable/contracts/token/ERC20/IERC20Upgradeable.sol";
import {IERC721Upgradeable} from "@openzeppelin-upgradable/contracts/token/ERC721/IERC721Upgradeable.sol";
import {IERC1155Upgradeable} from "@openzeppelin-upgradable/contracts/token/ERC1155/IERC1155Upgradeable.sol";

/// @title Base contract for Rentable
/// @author Rentable Team <hello@rentable.world>
/// @notice Implement simple security helpers for safe operations
contract BaseSecurityInitializable is Initializable, PausableUpgradeable {
    ///  Base security:
    ///  1. establish simple two-roles contract, _governance and _operator.
    ///  Operator can be changed only by _governance. Governance update needs acceptance.
    ///  2. can be paused by _operator or _governance via SCRAM()
    ///  3. only _governance can recover from pause via unpause
    ///  4. only _governance can withdraw in emergency
    ///  5. only _governance execute any tx in emergency

    /* ========== LIBRARIES ========== */
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ========== CONSTANTS ========== */
    address internal constant ETHER = address(0);

    /* ========== STATE VARIABLES ========== */
    // current governance address
    address internal _governance;
    // new governance address awaiting to be confirmed
    address internal _pendingGovernance;
    // operator address
    address internal _operator;

    /* ========== MODIFIERS ========== */

    /// @dev Prevents calling a function from anyone except governance
    modifier onlyGovernance() {
        require(msg.sender == _governance, "Only Governance");
        _;
    }

    /// @dev Prevents calling a function from anyone except governance or operator
    modifier onlyOperatorOrGovernance() {
        require(
            msg.sender == _operator || msg.sender == _governance,
            "Only Operator or Governance"
        );
        _;
    }

    /* ========== CONSTRUCTOR ========== */

    /* ---------- INITIALIZER ---------- */

    /// @dev For internal usage in the child initializers
    /// @param governance address for governance role
    /// @param operator address for operator role
    function __BaseSecurityInitializable_init(
        address governance,
        address operator
    ) internal onlyInitializing {
        __Pausable_init();

        _governance = governance;
        _operator = operator;
    }

    /* ========== SETTERS ========== */

    /// @notice Set governance
    /// @param governance governance address
    function setGovernance(address governance) external onlyGovernance {
        _pendingGovernance = governance;
    }

    /// @notice Accept proposed governance
    function acceptGovernance() external {
        require(msg.sender == _pendingGovernance, "Only Proposed Governance");

        _governance = _pendingGovernance;
        _pendingGovernance = address(0);
    }

    /// @notice Set operator
    /// @param operator _operator address
    function setOperator(address operator) external onlyGovernance {
        _operator = operator;
    }

    /* ========== VIEWS ========== */

    /// @notice Shows current governance
    /// @return governance address
    function getGovernance() external view returns (address) {
        return _governance;
    }

    /// @notice Shows upcoming governance
    /// @return upcoming pending governance address
    function getPendingGovernance() external view returns (address) {
        return _pendingGovernance;
    }

    /// @notice Shows current operator
    /// @return governance operator
    function getOperator() external view returns (address) {
        return _operator;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice Pause all operations
    function SCRAM() external onlyOperatorOrGovernance {
        _pause();
    }

    /// @notice Returns to normal state
    function unpause() external onlyGovernance {
        _unpause();
    }

    /// @notice Withdraw asset ERC20 or ETH
    /// @param _assetAddress Asset to be withdrawn
    function emergencyWithdrawERC20ETH(address _assetAddress)
        external
        whenPaused
        onlyGovernance
    {
        uint256 assetBalance;
        if (_assetAddress == ETHER) {
            address self = address(this);
            assetBalance = self.balance;
            payable(msg.sender).transfer(assetBalance);
        } else {
            assetBalance = IERC20Upgradeable(_assetAddress).balanceOf(
                address(this)
            );
            IERC20Upgradeable(_assetAddress).safeTransfer(
                msg.sender,
                assetBalance
            );
        }
    }

    /// @notice Batch withdraw asset ERC721
    /// @param _assetAddress token address
    /// @param _tokenIds array of token ids
    function emergencyBatchWithdrawERC721(
        address _assetAddress,
        uint256[] calldata _tokenIds,
        bool _notSafe
    ) external whenPaused onlyGovernance {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            if (_notSafe) {
                IERC721Upgradeable(_assetAddress).transferFrom(
                    address(this),
                    msg.sender,
                    _tokenIds[i]
                );
            } else {
                IERC721Upgradeable(_assetAddress).safeTransferFrom(
                    address(this),
                    msg.sender,
                    _tokenIds[i]
                );
            }
        }
    }

    /// @notice Batch withdraw asset ERC1155
    /// @param _assetAddress token address
    /// @param _tokenIds array of token ids
    function emergencyBatchWithdrawERC1155(
        address _assetAddress,
        uint256[] calldata _tokenIds
    ) external whenPaused onlyGovernance {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 assetBalance = IERC1155Upgradeable(_assetAddress).balanceOf(
                address(this),
                _tokenIds[i]
            );
            IERC1155Upgradeable(_assetAddress).safeTransferFrom(
                address(this),
                msg.sender,
                _tokenIds[i],
                assetBalance,
                ""
            );
        }
    }

    /// @notice Execute any tx in emergency
    /// @param to target
    /// @param value ether value
    /// @param data function+data
    /// @param isDelegateCall true will execute a delegate call, false a call
    /// @param txGas gas to forward
    function emergencyExecute(
        address to,
        uint256 value,
        bytes memory data,
        bool isDelegateCall,
        uint256 txGas
    ) external payable whenPaused onlyGovernance {
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
