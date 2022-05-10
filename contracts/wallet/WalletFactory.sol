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

    // beacon for new wallets
    address private _beacon;

    // admin for new proxies
    address private _admin;

    /* ========== CONSTRUCTOR ========== */

    /// @dev Instatiate WalletFactory
    /// @param beacon beacon address
    /// @param admin proxy admin address
    constructor(address beacon, address admin) {
        _setBeacon(beacon);
        _setAdmin(admin);
    }

    /* ========== SETTERS ========== */

    /* ---------- Internal ---------- */

    /// @dev Set beacon for new wallets
    /// @param beacon beacon address
    function _setBeacon(address beacon) internal {
        // it's ok to se to 0x0, disabling factory
        // slither-disable-next-line missing-zero-check
        _beacon = beacon;
    }

    /// @dev Set proxy admin for new wallets
    /// @param admin proxy admin address
    function _setAdmin(address admin) internal {
        // it's ok to se to 0x0, new wallets will be not upgradable
        // slither-disable-next-line missing-zero-check
        _admin = admin;
    }

    /* ---------- Public ---------- */

    /// @notice Set beacon for new wallets
    /// @param beacon beacon address
    function setBeacon(address beacon) external onlyOwner {
        _setBeacon(beacon);
    }

    /// @notice Set proxy admin for new wallets
    /// @param admin proxy admin address
    function setAdmin(address admin) external onlyOwner {
        _setAdmin(admin);
    }

    /* ========== VIEWS ========== */

    /// @notice Get beacon to be used for proxies
    /// @return beacon address
    function getBeacon() external view returns (address beacon) {
        return _beacon;
    }

    /// @notice Get admin for proxies
    /// @return admin address
    function getAdmin() external view returns (address admin) {
        return _admin;
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
                new ImmutableAdminUpgradeableBeaconProxy(_beacon, _admin, _data)
            );
    }
}
