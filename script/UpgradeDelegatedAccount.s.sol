// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {DelegatedAccount} from "../src/DelegatedAccount.sol";

/// @notice Script to upgrade an existing DelegatedAccount proxy to a new implementation
/// @dev Run with: forge script script/UpgradeDelegatedAccount.s.sol --rpc-url <RPC_URL> --broadcast
contract UpgradeDelegatedAccountScript is Script {
    function run() public {
        // Load the proxy address from environment variable
        address proxy = vm.envAddress("PROXY");

        console.log("Upgrading proxy at:", proxy);

        vm.startBroadcast();

        // Deploy new implementation
        DelegatedAccount newImplementation = new DelegatedAccount();
        console.log("New implementation deployed at:", address(newImplementation));

        // Upgrade proxy to new implementation
        DelegatedAccount(payable(proxy)).upgradeToAndCall(address(newImplementation), "");

        console.log("Proxy upgraded successfully");

        vm.stopBroadcast();
    }

    /// @notice Upgrade with initialization data (for migrations that need to call a function)
    /// @dev Set INIT_DATA env var to the encoded function call, or leave empty for no init
    function runWithInitData() public {
        address proxy = vm.envAddress("PROXY");
        bytes memory initData = vm.envOr("INIT_DATA", bytes(""));

        console.log("Upgrading proxy at:", proxy);

        vm.startBroadcast();

        // Deploy new implementation
        DelegatedAccount newImplementation = new DelegatedAccount();
        console.log("New implementation deployed at:", address(newImplementation));

        // Upgrade proxy to new implementation with init data
        DelegatedAccount(payable(proxy)).upgradeToAndCall(address(newImplementation), initData);

        console.log("Proxy upgraded successfully");
        if (initData.length > 0) {
            console.log("Init data executed");
        }

        vm.stopBroadcast();
    }
}
