// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";

/// @dev Minimal interface for EIP-712 contracts that issue operator signatures.
///      Both DelegatedAccountFactory and DelegatedAccount implement these.
interface IEip712WithOperatorNonces {
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function operatorNonces(address operator) external view returns (uint256);
}

/// @notice Base contract with shared EIP-712 signing helpers for signing scripts.
abstract contract SignScript is Script {
    /// @dev Builds an EIP-712 digest from a verifying contract's domain separator and a struct hash.
    function _buildDigest(address verifyingContract, bytes32 structHash) internal view returns (bytes32) {
        bytes32 domainSeparator = IEip712WithOperatorNonces(verifyingContract).DOMAIN_SEPARATOR();
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    /// @dev Signs a digest with a private key or a connected wallet address (Ledger).
    function _sign(bytes32 digest, address signer, uint256 privKey) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = privKey != 0 ? vm.sign(privKey, digest) : vm.sign(signer, digest);
        return abi.encodePacked(r, s, v);
    }

}
