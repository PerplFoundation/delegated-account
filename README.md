# Delegated Account

A smart contract that holds an account on the Perpl Exchange with separated owner/operator roles.

## Overview

The DelegatedAccount contract enables market makers (MMs) to delegate trading operations to a hot wallet (operator) while maintaining full control over withdrawals and contract management through the owner role.

### How it works

```
Operator/Owner → DelegatedAccount (BeaconProxy) → Exchange
                       (fallback)
```

1. **Fallback forwarding**: Any call to DelegatedAccount (that doesn't match a direct function) is forwarded to the Exchange via `EXCHANGE.call(msg.data)`
2. **Operator allowlist**: When the operator calls, the fallback checks if the function selector is in the allowlist before forwarding
3. **Direct functions**: Some functions (`withdrawCollateral`, `createAccount`, etc.) are implemented directly on DelegatedAccount with their own access control
4. **Account ownership**: The Exchange account is owned by the DelegatedAccount contract address, not the owner/operator EOAs

### Roles

- **Owner (MM)**: Can withdraw funds, manage the contract, and execute any function on the exchange
- **Operator (hot wallet)**: Can execute trades but cannot withdraw funds
- **Beacon Owner (admin/multisig)**: Can upgrade all DelegatedAccount instances via the beacon

## Getting Started

All scripts use `vm.startBroadcast()` — pass the signer via CLI flag:
- `--private-key <key>` for EOA
- `--ledger` for Ledger hardware wallet

### Deployed Contracts

#### Monad Mainnet

| Contract | Address |
|----------|---------|
| Factory | `0x676ad363bb61AACc1480335729F75B21408490b9` |
| Exchange | `0x34B6552d57a35a1D042CcAe1951BD1C370112a6F` |

#### Monad Testnet

| Contract | Address |
|----------|---------|
| Factory | `0x0E9B6c0B46C51D12A6E7062634fba358E9A7AdBc` |
| Exchange | `0x1964C32f0bE608E7D29302AFF5E61268E72080cc` |

### 1. Create a DelegatedAccount

Anyone can create a DelegatedAccount via the factory:

```shell
export FACTORY=0x0E9B6c0B46C51D12A6E7062634fba358E9A7AdBc
export OWNER=0x...            # MM cold wallet
export OPERATOR=0x...         # Hot wallet
export EXCHANGE=0x1964C32f0bE608E7D29302AFF5E61268E72080cc

forge script script/DelegatedAccount.s.sol:CreateAccountScript \
  --rpc-url <RPC_URL> --broadcast --private-key <KEY>
```

### 2. Set Up the Exchange Account

Must be run by the DelegatedAccount **owner**. Sets exchange approval, creates an exchange account with an initial deposit, and optionally enables order forwarding. If the DelegatedAccount doesn't hold enough collateral tokens, the script transfers the deficit from the owner.

```shell
export DELEGATED_ACCOUNT=0x...  # From step 1 output
export DEPOSIT_AMOUNT=100000000 # Raw token units (min $100 = 100_000_000)
# export ENABLE_FORWARDING=true # Optional, defaults to false

forge script script/DelegatedAccount.s.sol:SetupDelegatedAccountScript \
  --rpc-url <RPC_URL> --broadcast --private-key <OWNER_KEY> \
  --gas-estimate-multiplier 300
```

## Development

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

### Test Structure

Tests follow the [Branching Tree Technique (BTT)](https://github.com/PaulRBerg/btt-examples) methodology:
- [test/DelegatedAccount.tree](test/DelegatedAccount.tree) - Unit tests (with mocks)
- [test/DelegatedAccount.fork.tree](test/DelegatedAccount.fork.tree) - Fork tests (against Monad testnet)

## Architecture

DelegatedAccount is deployed behind a **Beacon Proxy** via the `DelegatedAccountFactory`. All instances share the same beacon, so upgrading the beacon upgrades every DelegatedAccount in a single transaction.

```
DelegatedAccountFactory
  └── creates BeaconProxy instances
        └── delegates to UpgradeableBeacon → DelegatedAccount implementation
```

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
