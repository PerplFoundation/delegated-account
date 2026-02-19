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
///      When an operator is specified, they must provide an EIP-712 signature
///      proving they agreed to be assigned to this owner.
///      The exchange address is fixed at factory deployment and cannot be changed.
///      The beacon owner (admin/multisig) can upgrade all instances via beacon.upgradeTo().
contract DelegatedAccountFactory is EIP712 {
    // ============ Errors ============
    error ZeroAddress();
    error SignatureExpired();
    error InvalidSignature();

    // ============ Events ============
    event DelegatedAccountCreated(address indexed proxy, address indexed owner, address indexed operator);

    // ============ Constants ============
    /// @notice EIP-712 typehash for owner consent to create a DelegatedAccount.
    bytes32 public constant CREATE_TYPEHASH =
        keccak256("Create(address owner,address operator,uint256 nonce,uint256 deadline)");

    /// @notice EIP-712 typehash for operator assignment consent.
    bytes32 public constant ASSIGN_OPERATOR_TYPEHASH = keccak256("AssignOperator(address owner,uint256 deadline)");

    // ============ State ============
    UpgradeableBeacon public immutable beacon;
    address public immutable EXCHANGE;

    mapping(address => uint256) public nonces;

    // ============ Constructor ============
    /// @notice Deploys the factory and creates the beacon
    /// @param _implementation The initial DelegatedAccount implementation address
    /// @param _beaconOwner The address that can upgrade the beacon (admin/multisig)
    /// @param _exchange The Perpl Exchange address bound to all accounts created by this factory
    constructor(address _implementation, address _beaconOwner, address _exchange)
        EIP712("DelegatedAccountFactory", "1")
    {
        if (_implementation == address(0) || _beaconOwner == address(0) || _exchange == address(0)) {
            revert ZeroAddress();
        }
        beacon = new UpgradeableBeacon(_implementation, _beaconOwner);
        EXCHANGE = _exchange;
    }

    // ============ Factory ============

    /// @notice Deploy a new DelegatedAccount behind a BeaconProxy.
    ///         msg.sender becomes the owner of the new account.
    /// @dev If an operator is specified, they must provide an EIP-712 consent signature
    ///      proving they agreed to be assigned to msg.sender as owner.
    ///      Pass _operator = address(0) to create without an operator (no signature needed).
    /// @param _operator The initial operator address (hot wallet), or address(0) for none
    /// @param _opDeadline Unix timestamp after which the operator signature is invalid (ignored if no operator)
    /// @param _opSig EIP-712 signature from _operator over (owner, deadline) (ignored if no operator)
    /// @return proxy The address of the newly deployed DelegatedAccount proxy
    function create(address _operator, uint256 _opDeadline, bytes calldata _opSig) external returns (address proxy) {
        address owner = msg.sender;
        if (_operator != address(0)) {
            _verifyOperator(_operator, owner, _opDeadline, _opSig);
        }
        return _create(owner, _operator);
    }

    /// @notice Deploy a new DelegatedAccount using an EIP-712 signature from the owner
    /// @dev Allows a third party to create the account on behalf of the owner.
    ///      The owner signs off-chain over (owner, operator, nonce, deadline).
    ///      If an operator is specified, they must also provide an EIP-712 signature over (owner, deadline).
    /// @param _owner The owner address (MM)
    /// @param _operator The initial operator address (hot wallet), or address(0) for none
    /// @param _deadline Unix timestamp after which the owner signature is invalid
    /// @param _ownerSig EIP-712 signature from _owner over (owner, operator, nonce, deadline)
    /// @param _opDeadline Unix timestamp after which the operator signature is invalid (ignored if no operator)
    /// @param _opSig EIP-712 signature from _operator over (owner, deadline) (ignored if no operator)
    /// @return proxy The address of the newly deployed DelegatedAccount proxy
    function createWithSignature(
        address _owner,
        address _operator,
        uint256 _deadline,
        bytes calldata _ownerSig,
        uint256 _opDeadline,
        bytes calldata _opSig
    ) external returns (address proxy) {
        if (block.timestamp > _deadline) revert SignatureExpired();
        bytes32 digest =
            _hashTypedDataV4(keccak256(abi.encode(CREATE_TYPEHASH, _owner, _operator, nonces[_owner]++, _deadline)));
        if (ECDSA.recover(digest, _ownerSig) != _owner) revert InvalidSignature();
        if (_operator != address(0)) {
            _verifyOperator(_operator, _owner, _opDeadline, _opSig);
        }
        return _create(_owner, _operator);
    }

    // ============ Internal ============

    function _verifyOperator(address _operator, address _owner, uint256 _deadline, bytes calldata _sig) internal view {
        if (block.timestamp > _deadline) revert SignatureExpired();
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(ASSIGN_OPERATOR_TYPEHASH, _owner, _deadline)));
        if (ECDSA.recover(digest, _sig) != _operator) revert InvalidSignature();
    }

    function _create(address _owner, address _operator) internal returns (address proxy) {
        bytes memory initData =
            abi.encodeWithSelector(DelegatedAccount.initialize.selector, _owner, _operator, EXCHANGE);
        proxy = address(new BeaconProxy(address(beacon), initData));
        emit DelegatedAccountCreated(proxy, _owner, _operator);
    }
}
