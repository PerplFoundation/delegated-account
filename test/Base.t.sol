// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {DelegatedAccount} from "../src/DelegatedAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @notice Mock ERC20 token for testing
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @notice Mock Exchange contract for testing
contract MockExchange {
    uint256 public nextAccountId = 1;
    bool public shouldFail;
    bytes public failReason;

    mapping(uint256 => uint256) public accountBalances;

    function setShouldFail(bool _shouldFail, bytes memory _failReason) external {
        shouldFail = _shouldFail;
        failReason = _failReason;
    }

    // 0xcab13915
    function createAccount(uint256 amount) external returns (uint256) {
        if (shouldFail) {
            assembly {
                let ptr := mload(0x40)
                let len := mload(add(sload(failReason.slot), 0x20))
                mstore(ptr, len)
                revert(ptr, add(len, 0x20))
            }
        }
        uint256 id = nextAccountId++;
        accountBalances[id] = amount;
        return id;
    }

    // 0x6112fe2e
    function withdrawCollateral(uint256) external view {
        if (shouldFail) {
            assembly {
                revert(0, 0)
            }
        }
    }

    // 0x61bd6f44
    function xferAcctToProtocol(uint256) external view {
        if (shouldFail) {
            assembly {
                revert(0, 0)
            }
        }
    }

    // 0xbad4a01f
    function depositCollateral(uint256) external view {
        if (shouldFail) {
            assembly {
                revert(0, 0)
            }
        }
    }

    // Generic function for testing operator execute
    function someAllowedFunction(uint256 value) external view returns (uint256) {
        if (shouldFail) {
            assembly {
                revert(0, 0)
            }
        }
        return value * 2;
    }

    // Fallback for any other calls
    fallback() external {
        if (shouldFail) {
            assembly {
                revert(0, 0)
            }
        }
    }
}

/// @notice Base test contract with common setup and utilities for local mock testing
abstract contract Base_Test is Test {
    // ============ Contracts ============
    DelegatedAccount public delegatedAccount;
    DelegatedAccount public implementation;
    MockToken public mockToken;
    MockExchange public exchange;
    IERC20 public token;
    address public exchangeAddr;

    // ============ Addresses ============
    address public owner;
    address public operator;
    address public user;

    // ============ Constants ============
    uint256 public constant INITIAL_BALANCE = 1_000_000e18;
    uint256 public constant DEPOSIT_AMOUNT = 100_000e18;

    // ============ Selectors ============
    bytes4 public constant CREATE_ACCOUNT_SELECTOR = 0xcab13915;
    bytes4 public constant WITHDRAW_COLLATERAL_SELECTOR = 0x6112fe2e;
    bytes4 public constant XFER_ACCT_TO_PROTOCOL_SELECTOR = 0x61bd6f44;
    bytes4 public constant DEPOSIT_COLLATERAL_SELECTOR = 0xbad4a01f;

    // ============ Setup ============
    function setUp() public virtual {
        // Create addresses
        owner = makeAddr("owner");
        operator = makeAddr("operator");
        user = makeAddr("user");

        // Deploy mock contracts for local testing
        mockToken = new MockToken();
        exchange = new MockExchange();
        token = IERC20(address(mockToken));
        exchangeAddr = address(exchange);

        // Deploy implementation
        implementation = new DelegatedAccount();

        // Deploy proxy with initialization
        bytes memory initData =
            abi.encodeWithSelector(DelegatedAccount.initialize.selector, owner, operator, exchangeAddr, address(token));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        delegatedAccount = DelegatedAccount(payable(address(proxy)));

        // Fund accounts
        mockToken.mint(owner, INITIAL_BALANCE);
        mockToken.mint(operator, INITIAL_BALANCE);
        mockToken.mint(address(delegatedAccount), INITIAL_BALANCE);
    }

    // ============ Helpers ============

    /// @notice Create an account on the exchange via the DelegatedAccount
    function _createAccount(uint256 amount) internal {
        vm.prank(owner);
        delegatedAccount.createAccount(amount);
    }

    /// @notice Helper to encode function call data
    function _encodeWithdrawCollateral(uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(WITHDRAW_COLLATERAL_SELECTOR, amount);
    }

    function _encodeXferAcctToProtocol(uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(XFER_ACCT_TO_PROTOCOL_SELECTOR, amount);
    }
}
