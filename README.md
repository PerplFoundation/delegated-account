# Delegated Account

A smart contract that holds an account on the Perpl Exchange with separated owner/operator roles.

## Overview

The DelegatedAccount contract enables market makers (MMs) to delegate trading operations to a hot wallet (operator) while maintaining full control over withdrawals and contract management through the owner role.

## Design

DelegatedAccount acts as a **proxy contract** that forwards calls to the Perpl Exchange. You interact with it using the Exchange's ABI - calls are automatically forwarded via the fallback function.

```
Operator/Owner → DelegatedAccount → Exchange
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

### Default Operator Allowlist
TODO: double check if this list is correct or if we are missing any.

The operator can call these Exchange functions by default:
- `execOrder`, `execOrders`, `execPerpOps` - trading
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

Set environment variables:
```shell
export OWNER=0x...
export OPERATOR=0x...
export EXCHANGE=0x...
export COLLATERAL_TOKEN=0x...
```

Deploy:
```shell
forge script script/DelegatedAccount.s.sol:DelegatedAccountScript --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```

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
