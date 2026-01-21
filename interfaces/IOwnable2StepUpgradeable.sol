// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IOwnable2StepUpgradeable {
    function acceptOwnership() external;
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function renounceOwnership() external;
    function transferOwnership(address newOwner) external;
}
