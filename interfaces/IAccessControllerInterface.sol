// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IAccessControllerInterface {
    function hasAccess(address user, bytes memory data) external view returns (bool);
}
