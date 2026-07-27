// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {DelegatedAccount} from "../../src/DelegatedAccount.sol";
import {IExchange} from "../../interfaces/IExchange.sol";

/// @notice Shared operator-allowlist reconciliation for the scripts that need it.
abstract contract OperatorAllowlistScript is Script {
    /// @notice Grants every selector in `currentAllowlist()` and revokes every selector in
    ///         `staleAllowlist()`, skipping entries that are already in the desired state.
    /// @dev A DelegatedAccount's operator allowlist is written once, by `initialize()`, from the
    ///      selectors the *implementation* was compiled against. An implementation deployed before
    ///      an Exchange ABI change therefore keeps minting accounts whose operators are allowed to
    ///      call selectors that no longer exist, and are blocked from the ones that replaced them.
    ///      Running this lets an existing factory/beacon keep serving new accounts without a
    ///      redeployment. Once the implementation is redeployed, this becomes a no-op.
    ///      Caller must be the DelegatedAccount owner.
    function syncOperatorAllowlist(DelegatedAccount delegatedAccount) public {
        bytes4[] memory grant = currentAllowlist();
        for (uint256 i = 0; i < grant.length; i++) {
            if (!delegatedAccount.operatorAllowlist(grant[i])) {
                delegatedAccount.setOperatorAllowlist(grant[i], true);
                console.log("Allowlisted selector:");
                console.logBytes4(grant[i]);
            }
        }

        bytes4[] memory revoke = staleAllowlist();
        for (uint256 i = 0; i < revoke.length; i++) {
            if (delegatedAccount.operatorAllowlist(revoke[i])) {
                delegatedAccount.setOperatorAllowlist(revoke[i], false);
                console.log("Revoked stale selector:");
                console.logBytes4(revoke[i]);
            }
        }
    }

    /// @notice The operator allowlist implied by the Exchange interface this repo is built against.
    /// @dev Must mirror the allowlist written by `DelegatedAccount.initialize()`; the two are kept
    ///      in step by `test_CurrentAllowlist_MatchesInitializer`.
    function currentAllowlist() public pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](7);
        selectors[0] = IExchange.execOrder.selector;
        selectors[1] = IExchange.execOrders.selector;
        selectors[2] = IExchange.increasePositionCollateral.selector;
        selectors[3] = IExchange.requestDecreasePositionCollateral.selector;
        selectors[4] = IExchange.buyLiquidations.selector;
        selectors[5] = IExchange.depositCollateral.selector;
        selectors[6] = IExchange.allowOrderForwarding.selector;
    }

    /// @notice Selectors granted by older implementations that the operator should no longer hold:
    ///         signatures the Exchange has since changed, plus ones intentionally dropped from the
    ///         default allowlist. Leaving them set is dead or unwanted permission surface.
    /// @dev Hardcoded on purpose: these are historical values that must not move when
    ///      `interfaces/` is regenerated. Append to this list on future ABI breaks.
    function staleAllowlist() public pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](5);
        selectors[0] = 0x6b69ebbe; // execOrder, before OrderDesc gained maxNegPnlCollatBPS
        selectors[1] = 0xaf3176da; // execOrders, same OrderDesc change
        selectors[2] = 0x9c64b2b5; // requestDecreasePositionCollateral(uint256)
        selectors[3] = 0x4a1feb12; // decreasePositionCollateral(uint256,uint256,bool), no longer granted at all
        selectors[4] = 0x1eebd35e; // buyLiquidations, before BuyToLiquidateDesc changed
    }
}
