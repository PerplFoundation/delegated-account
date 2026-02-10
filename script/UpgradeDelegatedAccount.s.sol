// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {DelegatedAccount} from "../src/DelegatedAccount.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

/// @notice Step 1: Deploy a new DelegatedAccount implementation
/// @dev Run with: forge script script/UpgradeDelegatedAccount.s.sol:DeployImplementationScript --rpc-url <RPC_URL> --broadcast --private-key <KEY>
contract DeployImplementationScript is Script {
    function run() public {
        address beaconAddr = vm.envAddress("BEACON");

        UpgradeableBeacon beacon = UpgradeableBeacon(beaconAddr);
        console.log("Current implementation:", beacon.implementation());

        vm.startBroadcast();

        DelegatedAccount newImplementation = new DelegatedAccount();

        vm.stopBroadcast();

        console.log("New implementation deployed at:", address(newImplementation));
        console.log("");
        console.log("Next step:");
        console.log("  If EOA/Ledger: run UpgradeBeaconScript with NEW_IMPLEMENTATION=%s", address(newImplementation));
        console.log("  If multisig:   propose beacon.upgradeTo(%s) via Safe UI", address(newImplementation));
    }
}

/// @notice Step 2: Upgrade the beacon to point to a new implementation
/// @dev Run with: forge script script/UpgradeDelegatedAccount.s.sol:UpgradeBeaconScript --rpc-url <RPC_URL> --broadcast --ledger
///      Must be called by the beacon owner.
contract UpgradeBeaconScript is Script {
    function run() public {
        address beaconAddr = vm.envAddress("BEACON");
        address newImpl = vm.envAddress("NEW_IMPLEMENTATION");

        UpgradeableBeacon beacon = UpgradeableBeacon(beaconAddr);
        console.log("Current implementation:", beacon.implementation());
        console.log("Upgrading to:", newImpl);

        vm.startBroadcast();

        beacon.upgradeTo(newImpl);

        vm.stopBroadcast();

        console.log("Beacon upgraded successfully");
        console.log("All DelegatedAccount proxies now use:", newImpl);
    }
}
