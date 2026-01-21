// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IIBeaconUpgradeable {
    function implementation() external view returns (address);
}
