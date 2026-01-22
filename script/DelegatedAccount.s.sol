// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {DelegatedAccount} from "../src/DelegatedAccount.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DelegatedAccountScript is Script {
    function run() public {
        // Load deployment parameters from environment variables
        address owner = vm.envAddress("OWNER");
        address operator = vm.envAddress("OPERATOR");
        address exchange = vm.envAddress("EXCHANGE");
        address collateralToken = vm.envAddress("COLLATERAL_TOKEN");

        vm.startBroadcast();

        // Deploy implementation
        DelegatedAccount implementation = new DelegatedAccount();
        console.log("Implementation deployed at:", address(implementation));

        // Deploy proxy with initialization
        bytes memory initData =
            abi.encodeWithSelector(DelegatedAccount.initialize.selector, owner, operator, exchange, collateralToken);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        console.log("Proxy (DelegatedAccount) deployed at:", address(proxy));

        vm.stopBroadcast();
    }
}
