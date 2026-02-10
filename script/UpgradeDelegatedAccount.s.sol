// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {DelegatedAccount} from "../src/DelegatedAccount.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

/// @notice Script to upgrade all DelegatedAccount instances via the beacon
/// @dev Run with: forge script script/UpgradeDelegatedAccount.s.sol --rpc-url <RPC_URL> --broadcast
///      Must be called by the beacon owner.
contract UpgradeDelegatedAccountScript is Script {
    function run() public {
        // Load the beacon address (from factory.beacon() or directly)
        address beaconAddr = vm.envAddress("BEACON");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        UpgradeableBeacon beacon = UpgradeableBeacon(beaconAddr);
        console.log("Current implementation:", beacon.implementation());

        vm.startBroadcast(deployerPrivateKey);

        // Deploy new implementation
        DelegatedAccount newImplementation = new DelegatedAccount();
        console.log("New implementation deployed at:", address(newImplementation));

        // Upgrade beacon — all proxies now use the new implementation
        beacon.upgradeTo(address(newImplementation));

        console.log("Beacon upgraded successfully");
        console.log("All DelegatedAccount proxies now use:", address(newImplementation));

        vm.stopBroadcast();
    }
}
