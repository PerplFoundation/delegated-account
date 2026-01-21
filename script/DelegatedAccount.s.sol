// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {DelegatedAccount} from "../src/DelegatedAccount.sol";

contract DelegatedAccountScript is Script {
    function run() public {
        // Load deployment parameters from environment variables
        address owner = vm.envAddress("OWNER");
        address operator = vm.envAddress("OPERATOR");
        address exchange = vm.envAddress("EXCHANGE");
        address collateralToken = vm.envAddress("COLLATERAL_TOKEN");

        vm.startBroadcast();

        DelegatedAccount delegatedAccount = new DelegatedAccount(owner, operator, exchange, collateralToken);

        console.log("DelegatedAccount deployed at:", address(delegatedAccount));

        vm.stopBroadcast();
    }
}
