// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IOwnableUpgradeable {
    function owner() external view returns (address);
    function renounceOwnership() external;
    function transferOwnership(address newOwner) external;
}
