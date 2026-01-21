// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IUUPSUpgradeable {
    function proxiableUUID() external view returns (bytes32);
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
}
