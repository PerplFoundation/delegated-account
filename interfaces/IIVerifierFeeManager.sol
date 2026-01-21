// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

library Common {
    struct AddressAndWeight {
        address addr;
        uint64 weight;
    }
}

interface IIVerifierFeeManager {
    function processFee(bytes memory payload, bytes memory parameterPayload, address subscriber) external payable;
    function processFeeBulk(bytes[] memory payloads, bytes memory parameterPayload, address subscriber) external payable;
    function setFeeRecipients(bytes32 configDigest, Common.AddressAndWeight[] memory rewardRecipientAndWeights) external;
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
