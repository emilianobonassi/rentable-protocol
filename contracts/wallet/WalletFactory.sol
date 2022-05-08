// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

// Inheritance
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IWalletFactory} from "./IWalletFactory.sol";

// References
import {ImmutableAdminUpgradeableBeaconProxy} from "../upgradability/ImmutableAdminUpgradeableBeaconProxy.sol";

import {SimpleWallet} from "./SimpleWallet.sol";

/// @title Rentable wallet factory
/// @author Rentable Team <hello@rentable.world>
/// @notice Wallet factory
contract WalletFactory is Ownable, IWalletFactory {
    /* ========== STATE VARIABLES ========== */

    // logic for new wallets
    address private _logic;

    // admin for new proxies
    address private _admin;

    /* ========== CONSTRUCTOR ========== */

    /// @dev Instatiate WalletFactory
    /// @param logic logic address
    /// @param admin proxy admin address
    constructor(address logic, address admin) {
        _setLogic(logic);
        _setAdmin(admin);
    }

    /* ========== SETTERS ========== */

    /* ---------- Internal ---------- */

    /// @dev Set logic for new wallets
    /// @param logic logic address
    function _setLogic(address logic) internal {
        // it's ok to se to 0x0, disabling factory
        // slither-disable-next-line missing-zero-check
        _logic = logic;
    }

    /// @dev Set proxy admin for new wallets
    /// @param admin proxy admin address
    function _setAdmin(address admin) internal {
        // it's ok to se to 0x0, new wallets will be not upgradable
        // slither-disable-next-line missing-zero-check
        _admin = admin;
    }

    /* ---------- Public ---------- */

    /// @notice Set logic for new wallets
    /// @param logic logic address
    function setLogic(address logic) external onlyOwner {
        _setLogic(logic);
    }

    /// @notice Set proxy admin for new wallets
    /// @param admin proxy admin address
    function setAdmin(address admin) external onlyOwner {
        _setAdmin(admin);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @inheritdoc IWalletFactory
    function createWallet(address owner, address user)
        external
        override
        returns (address wallet)
    {
        bytes memory _data = abi.encodeWithSelector(
            SimpleWallet.initialize.selector,
            owner,
            user
        );

        return
            address(
                new ImmutableAdminUpgradeableBeaconProxy(_logic, _admin, _data)
            );
    }
}
