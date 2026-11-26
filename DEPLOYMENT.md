# Factory Deployment & Upgrades

All scripts use `vm.startBroadcast()` — pass the signer via CLI flag:
- `--private-key <key>` for EOA
- `--ledger` for Ledger hardware wallet

## Deploy the Factory (one-time)

```shell
export BEACON_OWNER=0x...  # Admin/multisig that can upgrade all instances
export EXCHANGE=0x...      # Perpl Exchange address (immutable)

forge script script/DelegatedAccount.s.sol:DeployFactoryScript \
  --rpc-url <RPC_URL> --broadcast --private-key <KEY>
```

This deploys the DelegatedAccount implementation, the UpgradeableBeacon, and the factory. The exchange address is stored as an immutable on the factory and cannot be changed after deployment.

## Upgrade

The beacon proxy pattern allows upgrading all DelegatedAccount instances in a single transaction. Only the beacon owner can upgrade.

### Step 1: Deploy new implementation

```shell
export BEACON=0x...  # Beacon address (from factory.beacon())

forge script script/UpgradeDelegatedAccount.s.sol:DeployImplementationScript \
  --rpc-url <RPC_URL> --broadcast --private-key <KEY>
```

### Step 2: Upgrade the beacon

**EOA / Ledger:**

```shell
export NEW_IMPLEMENTATION=0x...  # From step 1 output

forge script script/UpgradeDelegatedAccount.s.sol:UpgradeBeaconScript \
  --rpc-url <RPC_URL> --broadcast --ledger
```

**Multisig:** If the Beacon's owner is a multisig, propose `beacon.upgradeTo(<new_implementation>)` via the Safe UI.

## Exchange v1.1.7.6

The Exchange upgrade to v1.1.7.6 (mvp-sc-0.1 branch `feat/v1.1.7.6-dcp-ommf`) changes the selector of no function on the default operator allowlist. The only changed signature is `decreasePositionCollateral` (now six arguments, `0x5495086a` -> `0xa292c664`), which no DelegatedAccount implementation has ever granted. The deployed implementation therefore keeps working against the upgraded Exchange as it is, and **no beacon upgrade is required to survive the Exchange upgrade**.

This repo's own change for the release is a policy one. Three selectors join the default allowlist: `cancelDecreaseCollateralRequest` (`0xebcf1656`), because from v1.1.7.6 an operator with `execOrder` can cancel the request anyway through order type 8 (see the README's "Default Operator Allowlist"); and `execOrderV2` (`0x28d18da3`) and `execOrdersV2` (`0x81e54cba`), so that operators can name client order ids. The V2 envelope also carries a builder code and fee, which an owner can refuse by revoking both. That is the only difference between the deployed implementation and this one.

### What to run, and when

| Situation | Action |
|---|---|
| Existing account, owner wants the new default | `SyncOperatorAllowlistScript` (owner). It grants `cancelDecreaseCollateralRequest`, `execOrderV2` and `execOrdersV2` and is a no-op otherwise. Runs the same before or after the Exchange upgrade: the selectors exist on both versions. |
| Existing account, owner does not want the operator near decrease-collateral requests at all | `SetOperatorAllowlistScript` with `ALLOWED=false` for `0x4d8dc985` (`execOrder`), `0x39435dac` (`execOrders`), `0x28d18da3` (`execOrderV2`), `0x81e54cba` (`execOrdersV2`) and `0x171a5b81` (`requestDecreasePositionCollateral`). Revoking only the direct selector leaves the order-type path open. |
| Existing account, owner does not want the operator to name a builder code and fee | `SetOperatorAllowlistScript` with `ALLOWED=false` for `0x28d18da3` (`execOrderV2`) and `0x81e54cba` (`execOrdersV2`). |
| New accounts from the existing factory | Nothing extra: `SetupDelegatedAccountScript` already reconciles the allowlist against the current build at setup time. |
| New accounts should be born with the new default, without the reconciliation step | Redeploy the implementation and upgrade the beacon (steps above). Optional, and can be done at any time; it changes no storage and `initialize()` is not re-run on existing accounts, so they still need `SyncOperatorAllowlistScript`. |

### Before the Exchange upgrade

1. Tell the owners of delegated accounts what their operator can do from the upgrade block: file, rewrite or cancel the account's decrease-collateral request through `execOrder` (warning 1 of the Exchange upgrade guide). Point them at the two rows above.
2. Tell each operator about the sender-side changes listed in the README ("Notes for operators on Exchange v1.1.7.6"): `maxMatches` capped at 125, the 150-order limit per perpetual, `OrderRequestV3`.
3. Tell owners that `execOrderV2` / `execOrdersV2` are granted by default so operators can name client order ids, and that the same envelope lets the operator name a builder code and fee (warning 2 of the Exchange upgrade guide). The row above revokes both.

### After the Exchange upgrade

1. `InspectDelegatedAccountScript` on a representative account: the Exchange version line reads `1.7.6`, the default selectors read `[allowed]`, the stale ones `[blocked]`.
2. An operator sends an ordinary order through its account and it executes. The allowlisted selectors did not change, so a failure here is not an allowlist problem.
3. `getAccountPerpNumOrders` for any delegated account that may hold more than 150 resting orders in one perpetual (the Inspect script prints the account-wide count); tell the owner of each such account.
4. Regenerate `interfaces/` from the tagged release, not the branch, once it is tagged, and re-run the test suite. The fork tests pin a testnet block; move `DEFAULT_FORK_BLOCK_NUMBER` in `test/DelegatedAccount.fork.t.sol` past the testnet upgrade block so the version-guarded tests in `Fork_DecreaseCollateral_Test` stop skipping. The pinned block also has to stay inside the window of historical state the public RPC keeps, roughly the most recent 8M blocks.
