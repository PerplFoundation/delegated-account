// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {DelegatedAccount} from "./DelegatedAccount.sol";

/// @title DelegatedAccountFactory
/// @notice Factory for deploying DelegatedAccount instances behind BeaconProxy.
///         The beacon allows upgrading all instances in a single transaction.
/// @dev The owner must create the account, either by calling create() directly
///      or by providing an EIP-712 signature via createWithSignature().
///      The beacon owner (admin/multisig) can upgrade all instances via beacon.upgradeTo().
contract DelegatedAccountFactory is EIP712 {
    // ============ Errors ============
    error ZeroAddress();
    error Unauthorized();
    error SignatureExpired();
    error InvalidSignature();

    // ============ Events ============
    event DelegatedAccountCreated(address indexed proxy, address indexed owner, address indexed operator);

    // ============ Constants ============
    bytes32 public constant CREATE_TYPEHASH =
        keccak256("Create(address owner,address operator,address exchange,uint256 nonce,uint256 deadline)");

    // ============ State ============
    UpgradeableBeacon public immutable beacon;
    mapping(address => uint256) public nonces;

    // ============ Constructor ============
    /// @notice Deploys the factory and creates the beacon
    /// @param _implementation The initial DelegatedAccount implementation address
    /// @param _beaconOwner The address that can upgrade the beacon (admin/multisig)
    constructor(address _implementation, address _beaconOwner) EIP712("DelegatedAccountFactory", "1") {
        if (_implementation == address(0) || _beaconOwner == address(0)) {
            revert ZeroAddress();
        }
        beacon = new UpgradeableBeacon(_implementation, _beaconOwner);
    }

    // ============ Factory ============

    /// @notice Deploy a new DelegatedAccount behind a BeaconProxy
    /// @dev msg.sender must be the owner. Use createWithSignature() for delegated creation.
    /// @param _owner The owner address (MM)
    /// @param _operator The initial operator address (hot wallet), or address(0) for none
    /// @param _exchange The Perpl Exchange address (collateral token is fetched from it)
    /// @return proxy The address of the newly deployed DelegatedAccount proxy
    function create(address _owner, address _operator, address _exchange) external returns (address proxy) {
        if (msg.sender != _owner) revert Unauthorized();
        return _create(_owner, _operator, _exchange);
    }

    /// @notice Deploy a new DelegatedAccount using an EIP-712 signature from the owner
    /// @dev Allows a third party to create the account on behalf of the owner.
    ///      The owner signs off-chain over (owner, operator, exchange, nonce, deadline).
    /// @param _owner The owner address (MM)
    /// @param _operator The initial operator address (hot wallet), or address(0) for none
    /// @param _exchange The Perpl Exchange address (collateral token is fetched from it)
    /// @param _deadline Unix timestamp after which the signature is invalid
    /// @param _signature EIP-712 signature from _owner
    /// @return proxy The address of the newly deployed DelegatedAccount proxy
    function createWithSignature(
        address _owner,
        address _operator,
        address _exchange,
        uint256 _deadline,
        bytes calldata _signature
    ) external returns (address proxy) {
        if (block.timestamp > _deadline) revert SignatureExpired();
        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(CREATE_TYPEHASH, _owner, _operator, _exchange, nonces[_owner]++, _deadline))
        );
        if (ECDSA.recover(digest, _signature) != _owner) revert InvalidSignature();
        return _create(_owner, _operator, _exchange);
    }

    // ============ Internal ============

    function _create(address _owner, address _operator, address _exchange) internal returns (address proxy) {
        bytes memory initData =
            abi.encodeWithSelector(DelegatedAccount.initialize.selector, _owner, _operator, _exchange);
        proxy = address(new BeaconProxy(address(beacon), initData));
        emit DelegatedAccountCreated(proxy, _owner, _operator);
    }
}
