// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title DelegatedAccount
/// @notice A proxy-style contract that forwards calls to the Perpl Exchange.
///         Call this contract with the Exchange's ABI - calls are automatically forwarded.
///         - Owner (MM): Can call any Exchange function
///         - Operator (hot wallet): Can only call allowlisted functions
contract DelegatedAccount {
    using SafeERC20 for IERC20;

    // ============ Errors ============
    error OnlyOwner();
    error OnlyOwnerOrOperator();
    error SelectorNotAllowed(bytes4 selector);
    error CallFailed(bytes returnData);
    error ZeroAddress();
    error AccountAlreadyCreated();
    error AccountNotCreated();

    // ============ Events ============
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event AccountCreated(uint256 indexed accountId);
    event OperatorAllowlistUpdated(bytes4 indexed selector, bool allowed);

    // ============ State ============
    address public owner;
    address public operator;
    address public immutable EXCHANGE;
    IERC20 public immutable COLLATERAL_TOKEN;
    uint256 public accountId;

    // Operator allowlist - only these selectors can be called by operator
    mapping(bytes4 => bool) public operatorAllowlist;

    // Selector for withdrawCollateral (used in explicit withdrawal function)
    bytes4 private constant WITHDRAW_COLLATERAL = 0x6112fe2e;

    // ============ Modifiers ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    // ============ Constructor ============
    constructor(address _owner, address _operator, address _exchange, address _collateralToken) {
        if (_owner == address(0) || _exchange == address(0) || _collateralToken == address(0)) {
            revert ZeroAddress();
        }
        owner = _owner;
        operator = _operator;
        EXCHANGE = _exchange;
        COLLATERAL_TOKEN = IERC20(_collateralToken);

        // Give Exchange infinite approval (trusted contract)
        IERC20(_collateralToken).forceApprove(_exchange, type(uint256).max);

        // Initialize operator allowlist
        operatorAllowlist[0x6b69ebbe] = true; // execOrder(...)
        operatorAllowlist[0xaf3176da] = true; // execOrders(...,bool)
        operatorAllowlist[0x5bf9264c] = true; // execPerpOps(...)
        operatorAllowlist[0xf769f0d3] = true; // increasePositionCollateral(uint256,uint256)
        operatorAllowlist[0x9c64b2b5] = true; // requestDecreasePositionCollateral(uint256)
        operatorAllowlist[0x4a1feb12] = true; // decreasePositionCollateral(uint256,uint256,bool)
        operatorAllowlist[0x1eebd35e] = true; // buyLiquidations(...,bool)
        operatorAllowlist[0xbad4a01f] = true; // depositCollateral(uint256)
        operatorAllowlist[0x7962f910] = true; // allowOrderForwarding(bool)
    }

    // ============ Fallback - Forwards calls to Exchange ============

    /// @notice Forwards any call to the Exchange contract
    /// @dev Owner can call anything; operator can only call allowlisted functions
    fallback() external payable {
        address _owner = owner;
        address _operator = operator;

        // Must be owner or operator
        if (msg.sender != _owner && msg.sender != _operator) {
            revert OnlyOwnerOrOperator();
        }

        // Check allowlist for operator
        if (msg.sender == _operator) {
            if (accountId == 0) revert AccountNotCreated();
            if (msg.data.length < 4) revert SelectorNotAllowed(bytes4(0));
            bytes4 selector = bytes4(msg.data[:4]);
            if (!operatorAllowlist[selector]) {
                revert SelectorNotAllowed(selector);
            }
        }

        // Forward call to Exchange
        (bool success, bytes memory returnData) = EXCHANGE.call(msg.data);

        // Bubble up the result
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }

        // Return the result
        assembly {
            return(add(returnData, 32), mload(returnData))
        }
    }

    receive() external payable {}

    // ============ Owner Management ============

    /// @notice Transfer ownership to a new address
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Update the operator address
    function setOperator(address newOperator) external onlyOwner {
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    /// @notice Update operator allowlist
    /// @param selector The function selector
    /// @param allowed Whether the operator can call this function
    function setOperatorAllowlist(bytes4 selector, bool allowed) external onlyOwner {
        operatorAllowlist[selector] = allowed;
        emit OperatorAllowlistUpdated(selector, allowed);
    }

    // ============ Account Setup ============

    /// @notice Create an account on the exchange
    /// @dev Contract must have tokens before calling (infinite approval to Exchange set in constructor)
    /// @param amount Initial deposit amount
    function createAccount(uint256 amount) external onlyOwner {
        if (accountId != 0) revert AccountAlreadyCreated();

        (bool success, bytes memory returnData) = EXCHANGE.call(abi.encodeWithSelector(0xcab13915, amount)); // createAccount(uint256)
        if (!success) revert CallFailed(returnData);

        accountId = abi.decode(returnData, (uint256));
        emit AccountCreated(accountId);
    }

    // ============ Withdrawal ============

    /// @notice Withdraw collateral from the exchange to the owner
    /// @dev This explicit function ensures tokens are transferred to owner after withdrawal
    function withdrawCollateral(uint256 amount) external onlyOwner {
        (bool success, bytes memory returnData) = EXCHANGE.call(abi.encodeWithSelector(WITHDRAW_COLLATERAL, amount));
        if (!success) revert CallFailed(returnData);

        // Transfer withdrawn tokens to owner
        uint256 balance = COLLATERAL_TOKEN.balanceOf(address(this));
        if (balance > 0) {
            COLLATERAL_TOKEN.safeTransfer(owner, balance);
        }
    }

    /// @notice Transfer tokens from this contract to owner
    function rescueTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner, amount);
    }
}
