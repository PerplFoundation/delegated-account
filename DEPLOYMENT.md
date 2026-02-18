# Factory Deployment & Upgrades

All scripts use `vm.startBroadcast()` — pass the signer via CLI flag:
- `--private-key <key>` for EOA
- `--ledger` for Ledger hardware wallet

## Deploy the Factory (one-time)

```shell
export BEACON_OWNER=0x...  # Admin/multisig that can upgrade all instances

forge script script/DelegatedAccount.s.sol:DeployFactoryScript \
  --rpc-url <RPC_URL> --broadcast --private-key <KEY>
```

This deploys the DelegatedAccount implementation, the UpgradeableBeacon, and the factory.

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
