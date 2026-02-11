# Delegated Account

A smart contract that holds an account on the Perpl Exchange with separated owner/operator roles.

## Overview

The DelegatedAccount contract enables market makers (MMs) to delegate trading operations to a hot wallet (operator) while maintaining full control over withdrawals and contract management through the owner role.

## Design

DelegatedAccount is deployed behind a **Beacon Proxy** via the `DelegatedAccountFactory`. You interact with it using the Exchange's ABI - calls are automatically forwarded via the fallback function. All instances share the same beacon, so upgrading the beacon upgrades every DelegatedAccount in a single transaction.

```
DelegatedAccountFactory
  └── creates BeaconProxy instances
        └── delegates to UpgradeableBeacon → DelegatedAccount implementation

Operator/Owner → DelegatedAccount (BeaconProxy) → Exchange
                       (fallback)
```

### How it works

1. **Fallback forwarding**: Any call to DelegatedAccount (that doesn't match a direct function) is forwarded to the Exchange via `EXCHANGE.call(msg.data)`
2. **Operator allowlist**: When the operator calls, the fallback checks if the function selector is in the allowlist before forwarding
3. **Direct functions**: Some functions (`withdrawCollateral`, `createAccount`, etc.) are implemented directly on DelegatedAccount with their own access control
4. **Account ownership**: The Exchange account is owned by the DelegatedAccount contract address, not the owner/operator EOAs

### Roles

- **Owner (MM)**: Can withdraw funds, manage the contract, and execute any function on the exchange
- **Operator (hot wallet)**: Can execute trades but cannot withdraw funds
- **Beacon Owner (admin/multisig)**: Can upgrade all DelegatedAccount instances via the beacon

### Default Operator Allowlist

The operator can call these Exchange functions by default:
- `execOrder`, `execOrders` - trading
- `increasePositionCollateral`, `requestDecreasePositionCollateral`, `decreasePositionCollateral` - position management
- `buyLiquidations` - liquidation buying
- `depositCollateral` - deposits (via fallback)
- `allowOrderForwarding` - order forwarding permission (TODO: should we keep this one?)

### Security

The operator is restricted:
- **Permanently blocked**: `withdrawCollateral` - DelegatedAccount has a direct owner-only function that overrides the fallback
- **Not in default allowlist**: `xferAcctToProtocol` - moves funds to protocol balance (owner can add to allowlist if needed)

The owner can modify the operator allowlist via `setOperatorAllowlist(selector, allowed)`.

## Usage

### Build

```shell
forge build
```

### Test

Unit tests (with mocks):
```shell
forge test --no-match-contract Fork
```

Fork tests against Monad testnet (uses real exchange contract):
```shell
forge test --fork-url https://monad-testnet.drpc.org --match-contract Fork
```

All tests:
```shell
forge test --fork-url https://monad-testnet.drpc.org
```

### Deploy

All scripts use `vm.startBroadcast()` — pass the signer via CLI flag:
- `--private-key <key>` for EOA
- `--ledger` for Ledger hardware wallet

#### 1. Deploy the Factory (one-time)

```shell
export BEACON_OWNER=0x...  # Admin/multisig that can upgrade all instances

forge script script/DelegatedAccount.s.sol:DeployFactoryScript \
  --rpc-url <RPC_URL> --broadcast --private-key <KEY>
```

This deploys the DelegatedAccount implementation, the UpgradeableBeacon, and the factory.

#### 2. Create a DelegatedAccount

```shell
export FACTORY=0x...          # Factory address from step 1
export OWNER=0x...            # MM cold wallet
export OPERATOR=0x...         # Hot wallet
export EXCHANGE=0x...         # Collateral token is fetched from exchange automatically

forge script script/DelegatedAccount.s.sol:CreateAccountScript \
  --rpc-url <RPC_URL> --broadcast --private-key <KEY>
```

### Upgrade

The beacon proxy pattern allows upgrading all DelegatedAccount instances in a single transaction. Only the beacon owner can upgrade.

#### Step 1: Deploy new implementation

```shell
export BEACON=0x...  # Beacon address (from factory.beacon())

forge script script/UpgradeDelegatedAccount.s.sol:DeployImplementationScript \
  --rpc-url <RPC_URL> --broadcast --private-key <KEY>
```

#### Step 2: Upgrade the beacon

**EOA / Ledger:**

```shell
export NEW_IMPLEMENTATION=0x...  # From step 1 output

forge script script/UpgradeDelegatedAccount.s.sol:UpgradeBeaconScript \
  --rpc-url <RPC_URL> --broadcast --ledger
```

**Multisig:** If the Beacon's owner is a multisig, propose `beacon.upgradeTo(<new_implementation>)` via the Safe UI.

## Test Structure

Tests follow the [Branching Tree Technique (BTT)](https://github.com/PaulRBerg/btt-examples) methodology:
- [test/DelegatedAccount.tree](test/DelegatedAccount.tree) - Unit tests (with mocks)
- [test/DelegatedAccount.fork.tree](test/DelegatedAccount.fork.tree) - Fork tests (against Monad testnet)

## Monad Testnet

| Contract | Address |
|----------|---------|
| Exchange | `0x9c216d1ab3e0407b3d6f1d5e9effe6d01c326ab7` |
| Collateral Token | `0xdF5B718D8fCc173335185a2A1513Ee8151E3C027` |

RPC: `https://monad-testnet.drpc.org`

## Generating Interfaces

To generate Solidity interfaces from contracts in another project, set the `PERPL_PROJECT_PATH` environment variable and run the script:

```shell
# Set the path to your project (adjust as needed)
export PERPL_PROJECT_PATH=../mvp-sc-0.1

# Generate interfaces (compiles automatically using the perpl profile)
./script/gen-interfaces-forge.sh
```

Or as a one-liner:

```shell
PERPL_PROJECT_PATH=../mvp-sc-0.1 ./script/gen-interfaces-forge.sh
```

The generated interfaces will be placed in `./interfaces/`.

### Requirements

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (forge, cast)
- jq

## License

BUSL-1.1
