// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {DelegatedAccount} from "./DelegatedAccount.sol";

/// @title DelegatedAccountFactory
/// @notice Factory for deploying DelegatedAccount instances behind BeaconProxy.
///         The beacon allows upgrading all instances in a single transaction.
/// @dev Anyone can call create() to deploy a new DelegatedAccount.
///      The beacon owner (admin/multisig) can upgrade all instances via beacon.upgradeTo().
contract DelegatedAccountFactory {
    // ============ Errors ============
    error ZeroAddress();

    // ============ Events ============
    event DelegatedAccountCreated(address indexed proxy, address indexed owner, address indexed operator);

    // ============ State ============
    UpgradeableBeacon public immutable beacon;

    // ============ Constructor ============
    /// @notice Deploys the factory and creates the beacon
    /// @param _implementation The initial DelegatedAccount implementation address
    /// @param _beaconOwner The address that can upgrade the beacon (admin/multisig)
    constructor(address _implementation, address _beaconOwner) {
        if (_implementation == address(0) || _beaconOwner == address(0)) {
            revert ZeroAddress();
        }
        beacon = new UpgradeableBeacon(_implementation, _beaconOwner);
    }

    // ============ Factory ============

    /// @notice Deploy a new DelegatedAccount behind a BeaconProxy
    /// @param _owner The owner address (MM)
    /// @param _operator The initial operator address (hot wallet), or address(0) for none
    /// @param _exchange The Perpl Exchange address (collateral token is fetched from it)
    /// @return proxy The address of the newly deployed DelegatedAccount proxy
    function create(address _owner, address _operator, address _exchange) external returns (address proxy) {
        bytes memory initData =
            abi.encodeWithSelector(DelegatedAccount.initialize.selector, _owner, _operator, _exchange);
        proxy = address(new BeaconProxy(address(beacon), initData));
        emit DelegatedAccountCreated(proxy, _owner, _operator);
    }
}
