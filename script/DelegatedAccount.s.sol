// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {DelegatedAccount} from "../src/DelegatedAccount.sol";
import {DelegatedAccountFactory} from "../src/DelegatedAccountFactory.sol";
import {IExchange} from "../interfaces/IExchange.sol";
import {IEip712WithOperatorNonces, SignScript} from "./helpers/SignScript.sol";

/// @notice Deploys the DelegatedAccountFactory (implementation + beacon created internally)
/// @dev Run with: forge script script/DelegatedAccount.s.sol --rpc-url <RPC_URL> --broadcast --private-key <KEY>
///      Or with Ledger: forge script script/DelegatedAccount.s.sol --rpc-url <RPC_URL> --broadcast --ledger
contract DeployFactoryScript is Script {
    function run() public {
        address beaconOwner = vm.envAddress("BEACON_OWNER");
        address exchange = vm.envAddress("EXCHANGE");

        vm.startBroadcast();

        // Deploy implementation
        DelegatedAccount implementation = new DelegatedAccount();
        console.log("Implementation deployed at:", address(implementation));

        // Deploy factory (creates beacon internally)
        DelegatedAccountFactory factory = new DelegatedAccountFactory(address(implementation), beaconOwner, exchange);
        console.log("Factory deployed at:", address(factory));
        console.log("Beacon deployed at:", address(factory.beacon()));
        console.log("Beacon owner:", beaconOwner);
        console.log("Exchange:", exchange);

        vm.stopBroadcast();
    }
}

/// @notice Creates a new DelegatedAccount via the factory.
///         The broadcast signer becomes the owner of the new account.
/// @dev Operator is optional.
///
///      Without operator:
///        forge script script/DelegatedAccount.s.sol:CreateAccountScript \
///          --rpc-url <RPC_URL> --broadcast --private-key <OWNER_KEY>
///
///      With operator:
///        export OPERATOR=0x...
///        export OP_DEADLINE=<unix_timestamp>
///        export OP_SIG=0x<hex_encoded_sig>
///        forge script script/DelegatedAccount.s.sol:CreateAccountScript \
///          --rpc-url <RPC_URL> --broadcast --private-key <OWNER_KEY>
contract CreateAccountScript is Script {
    function run() public {
        address factoryAddr = vm.envAddress("FACTORY");
        address operator = vm.envOr("OPERATOR", address(0));
        uint256 opDeadline = vm.envOr("OP_DEADLINE", uint256(0));
        bytes memory opSig = vm.envOr("OP_SIG", new bytes(0));

        vm.startBroadcast();

        DelegatedAccountFactory factory = DelegatedAccountFactory(factoryAddr);
        address proxy = factory.create(operator, opDeadline, opSig);

        console.log("DelegatedAccount deployed at:", proxy);
        console.log("Exchange:", factory.EXCHANGE());
        if (operator != address(0)) {
            console.log("Operator:", operator);
        }

        vm.stopBroadcast();
    }
}

/// @notice Generates an EIP-712 AssignOperator signature for operator consent.
///         Pass the relevant contract as VERIFYING_CONTRACT:
///           - Factory address: for factory.create() or factory.createWithSignature()
///           - DelegatedAccount address: for delegatedAccount.addOperator()
///         Domain separator and current nonce are fetched from the contract on-chain.
/// @dev export VERIFYING_CONTRACT=<address>
///      export OWNER=<owner_address>
///      export DEADLINE=<unix_timestamp>
///      export PRIVATE_KEY=<operator_private_key>
///      forge script script/DelegatedAccount.s.sol:SignOperatorScript --rpc-url <RPC_URL>
contract SignOperatorScript is SignScript {
    bytes32 constant ASSIGN_OPERATOR_TYPEHASH =
        keccak256("AssignOperator(address owner,uint256 nonce,uint256 deadline)");

    function run() public view {
        address verifyingContract = vm.envAddress("VERIFYING_CONTRACT");
        address owner = vm.envAddress("OWNER");
        uint256 deadline = vm.envUint("DEADLINE");
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        address operator = vm.addr(privKey);

        (bytes memory sig, uint256 nonce) = sign(verifyingContract, owner, operator, deadline, privKey);

        console.log("Operator:     ", operator);
        console.log("Owner:        ", owner);
        console.log("Nonce used:   ", nonce);
        console.log("Deadline:     ", deadline);
        console.log("Signature:");
        console.logBytes(sig);
    }

    /// @notice Generate an AssignOperator EIP-712 signature.
    ///         Can be called directly from tests to avoid duplicating signing logic.
    /// @param verifyingContract Factory address (for create/createWithSignature) or DelegatedAccount address (for addOperator)
    /// @param owner The owner address the operator is consenting to be assigned to
    /// @param operator The operator address (signer)
    /// @param deadline Unix timestamp after which the signature is invalid
    /// @param privKey Operator's private key
    /// @return sig The EIP-712 signature bytes
    /// @return nonce The operator nonce used
    function sign(address verifyingContract, address owner, address operator, uint256 deadline, uint256 privKey)
        public
        view
        returns (bytes memory sig, uint256 nonce)
    {
        nonce = IEip712WithOperatorNonces(verifyingContract).operatorNonces(operator);
        bytes32 digest =
            _buildDigest(verifyingContract, keccak256(abi.encode(ASSIGN_OPERATOR_TYPEHASH, owner, nonce, deadline)));
        sig = _sign(digest, operator, privKey);
    }
}

/// @notice Generates an EIP-712 Create signature for owner consent (createWithSignature).
///         Current nonce is fetched from the factory on-chain.
/// @dev Hot wallet (private key):
///        export FACTORY=<factory_address>
///        export OPERATOR=<operator_address>  # optional, defaults to address(0)
///        export DEADLINE=<unix_timestamp>
///        export PRIVATE_KEY=<owner_private_key>
///        forge script script/DelegatedAccount.s.sol:SignCreateScript --rpc-url <RPC_URL>
contract SignCreateScript is SignScript {
    bytes32 constant CREATE_TYPEHASH =
        keccak256("Create(address owner,address operator,uint256 nonce,uint256 deadline)");

    function run() public view {
        address factoryAddr = vm.envAddress("FACTORY");
        address operator = vm.envOr("OPERATOR", address(0));
        uint256 deadline = vm.envUint("DEADLINE");
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(privKey);

        (bytes memory sig, uint256 nonce) = sign(factoryAddr, owner, operator, deadline, privKey);

        console.log("Owner:        ", owner);
        console.log("Operator:     ", operator);
        console.log("Nonce used:   ", nonce);
        console.log("Deadline:     ", deadline);
        console.log("Signature:");
        console.logBytes(sig);
    }

    /// @notice Generate a Create EIP-712 signature for factory.createWithSignature().
    ///         Can be called directly from tests to avoid duplicating signing logic.
    /// @param factoryAddr The DelegatedAccountFactory address
    /// @param owner The owner address (signer)
    /// @param operator The operator address (or address(0) for none)
    /// @param deadline Unix timestamp after which the signature is invalid
    /// @param privKey Owner's private key
    /// @return sig The EIP-712 signature bytes
    /// @return nonce The owner nonce used
    function sign(address factoryAddr, address owner, address operator, uint256 deadline, uint256 privKey)
        public
        view
        returns (bytes memory sig, uint256 nonce)
    {
        nonce = DelegatedAccountFactory(factoryAddr).nonces(owner);
        bytes32 digest =
            _buildDigest(factoryAddr, keccak256(abi.encode(CREATE_TYPEHASH, owner, operator, nonce, deadline)));
        sig = _sign(digest, owner, privKey);
    }
}

/// @notice Sets exchange approval, creates exchange account, and optionally enables forwarding
/// @dev Must be run by the DelegatedAccount owner.
///      Run with: forge script script/DelegatedAccount.s.sol:SetupDelegatedAccountScript --rpc-url <RPC_URL> --broadcast --private-key <OWNER_KEY>
///      Or with Ledger: forge script script/DelegatedAccount.s.sol:SetupDelegatedAccountScript --rpc-url <RPC_URL> --broadcast --ledger
contract SetupDelegatedAccountScript is Script {
    using SafeERC20 for IERC20;

    uint256 constant MIN_DEPOSIT = 100_000_000; // Exchange's minimum for account creation

    function run() public {
        address delegatedAccountAddr = vm.envAddress("DELEGATED_ACCOUNT");
        uint256 depositAmount = vm.envUint("DEPOSIT_AMOUNT");
        bool enableForwarding = vm.envOr("ENABLE_FORWARDING", false);

        if (depositAmount < MIN_DEPOSIT) revert("DEPOSIT_AMOUNT below minimum");

        DelegatedAccount delegatedAccount = DelegatedAccount(payable(delegatedAccountAddr));
        IERC20 collateralToken = delegatedAccount.collateralToken();

        vm.startBroadcast();

        // Transfer collateral tokens to the DelegatedAccount if needed
        uint256 balance = collateralToken.balanceOf(delegatedAccountAddr);
        if (balance < depositAmount) {
            uint256 deficit = depositAmount - balance;
            collateralToken.safeTransfer(delegatedAccountAddr, deficit);
            console.log("Transferred collateral:", deficit);
        }

        // Set exchange approval for the deposit amount
        delegatedAccount.setExchangeApproval(depositAmount);
        console.log("Exchange approval set to:", depositAmount);

        // Create exchange account with initial deposit
        delegatedAccount.createAccount(depositAmount);
        console.log("Exchange account created with deposit:", depositAmount);
        console.log("Account ID:", delegatedAccount.accountId());

        // Optionally enable order forwarding
        if (enableForwarding) {
            IExchange(delegatedAccountAddr).allowOrderForwarding(true);
            console.log("Order forwarding enabled");
        }

        vm.stopBroadcast();
    }
}
