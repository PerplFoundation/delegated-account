// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IIERC1822ProxiableUpgradeable {
    function proxiableUUID() external view returns (bytes32);
}
