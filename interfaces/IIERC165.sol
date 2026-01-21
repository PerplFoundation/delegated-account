// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IIERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
