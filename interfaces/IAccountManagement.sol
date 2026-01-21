// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IAccountManagement {
    function acceptOwnership() external;
    function addressBlocked(address) external view returns (bool);
    function allowOrderForwarding(bool allow) external;
    function createAccount(uint256 amountCNS) external returns (uint256 accountId);
    function depositCollateral(uint256 amountCNS) external;
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function renounceOwnership() external;
    function transferOwnership(address newOwner) external;
    function whitelisted(address) external view returns (bool);
    function whitelistingEnabled() external view returns (bool);
    function withdrawCollateral(uint256 amountCNS) external;
    function xferAcctToProtocol(uint256 amountCNS) external;
}
