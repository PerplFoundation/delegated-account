// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IOracle {
    function acceptOwnership() external;
    function addressBlocked(address) external view returns (bool);
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function renounceOwnership() external;
    function transferOwnership(address newOwner) external;
    function whitelisted(address) external view returns (bool);
    function whitelistingEnabled() external view returns (bool);
}
