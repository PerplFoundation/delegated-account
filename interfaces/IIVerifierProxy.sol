// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

library Common {
    struct AddressAndWeight {
        address addr;
        uint64 weight;
    }
}

interface IIVerifierProxy {
    function getVerifier(bytes32 configDigest) external view returns (address verifierAddress);
    function initializeVerifier(address verifierAddress) external;
    function setAccessController(address accessController) external;
    function setFeeManager(address feeManager) external;
    function setVerifier(
        bytes32 currentConfigDigest,
        bytes32 newConfigDigest,
        Common.AddressAndWeight[] memory addressesAndWeights
    ) external;
    function unsetVerifier(bytes32 configDigest) external;
    function verify(bytes memory payload, bytes memory parameterPayload)
        external
        payable
        returns (bytes memory verifierResponse);
    function verifyBulk(bytes[] memory payloads, bytes memory parameterPayload)
        external
        payable
        returns (bytes[] memory verifiedReports);
}
