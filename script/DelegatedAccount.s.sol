// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {DelegatedAccount} from "../src/DelegatedAccount.sol";
import {DelegatedAccountFactory} from "../src/DelegatedAccountFactory.sol";

/// @notice Deploys the DelegatedAccountFactory (implementation + beacon created internally)
/// @dev Run with: forge script script/DelegatedAccount.s.sol --rpc-url <RPC_URL> --broadcast --private-key <KEY>
///      Or with Ledger: forge script script/DelegatedAccount.s.sol --rpc-url <RPC_URL> --broadcast --ledger
contract DeployFactoryScript is Script {
    function run() public {
        address beaconOwner = vm.envAddress("BEACON_OWNER");

        vm.startBroadcast();

        // Deploy implementation
        DelegatedAccount implementation = new DelegatedAccount();
        console.log("Implementation deployed at:", address(implementation));

        // Deploy factory (creates beacon internally)
        DelegatedAccountFactory factory = new DelegatedAccountFactory(address(implementation), beaconOwner);
        console.log("Factory deployed at:", address(factory));
        console.log("Beacon deployed at:", address(factory.beacon()));
        console.log("Beacon owner:", beaconOwner);

        vm.stopBroadcast();
    }
}

/// @notice Creates a new DelegatedAccount via the factory
/// @dev Run with: forge script script/DelegatedAccount.s.sol:CreateAccountScript --rpc-url <RPC_URL> --broadcast --private-key <KEY>
///      Or with Ledger: forge script script/DelegatedAccount.s.sol:CreateAccountScript --rpc-url <RPC_URL> --broadcast --ledger
contract CreateAccountScript is Script {
    function run() public {
        address factoryAddr = vm.envAddress("FACTORY");
        address owner = vm.envAddress("OWNER");
        address operator = vm.envAddress("OPERATOR");
        address exchange = vm.envAddress("EXCHANGE");

        vm.startBroadcast();

        DelegatedAccountFactory factory = DelegatedAccountFactory(factoryAddr);
        address proxy = factory.create(owner, operator, exchange);

        console.log("DelegatedAccount deployed at:", proxy);
        console.log("Owner:", owner);
        console.log("Operator:", operator);

        vm.stopBroadcast();
    }
}
