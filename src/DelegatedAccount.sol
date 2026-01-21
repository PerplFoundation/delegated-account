// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title DelegatedAccount
/// @notice A proxy-style contract that forwards calls to the Perpl Exchange.
///         Call this contract with the Exchange's ABI - calls are automatically forwarded.
///         - Owner (MM): Can call any Exchange function
///         - Operator (hot wallet): Can only call allowlisted functions
contract DelegatedAccount is Ownable2Step {
    using SafeERC20 for IERC20;

    // ============ Errors ============
    error OnlyOwnerOrOperator();
    error SelectorNotAllowed(bytes4 selector);
    error CallFailed(bytes returnData);
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error InvalidReturnData();
    error AccountAlreadyCreated();
    error AccountNotCreated();

    // ============ Events ============
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event AccountCreated(uint256 indexed accountId);
    event OperatorAllowlistUpdated(bytes4 indexed selector, bool allowed);
    event ExchangeApprovalUpdated(uint256 amount);

    // ============ State ============
    address public operator;
    address public immutable EXCHANGE;
    IERC20 public immutable COLLATERAL_TOKEN;
    uint256 public accountId;

    // Operator allowlist - only these selectors can be called by operator
    mapping(bytes4 => bool) public operatorAllowlist;

    // ============ Function Selectors ============
    // withdrawCollateral(uint256) - used in explicit withdrawal function
    bytes4 private constant WITHDRAW_COLLATERAL = 0x6112fe2e;
    // createAccount(uint256) - used in account creation
    bytes4 private constant CREATE_ACCOUNT = 0xcab13915;

    // ============ Constructor ============
    constructor(address _owner, address _operator, address _exchange, address _collateralToken) Ownable(_owner) {
        if (_exchange == address(0) || _collateralToken == address(0)) {
            revert ZeroAddress();
        }
        operator = _operator;
        EXCHANGE = _exchange;
        COLLATERAL_TOKEN = IERC20(_collateralToken);

        // Give Exchange infinite approval (trusted contract)
        IERC20(_collateralToken).forceApprove(_exchange, type(uint256).max);

        // Initialize operator allowlist with Exchange function selectors
        // Selector: bytes4(keccak256("functionSignature"))
        operatorAllowlist[0x6b69ebbe] = true; // execOrder(uint256,(address,uint256,uint256,uint256,uint256,uint256,bool,uint8),bytes,(address,uint256,uint256,uint256,uint256,uint256,bool,uint8),bytes)
        operatorAllowlist[0xaf3176da] = true; // execOrders((uint256,(address,uint256,uint256,uint256,uint256,uint256,bool,uint8),bytes,(address,uint256,uint256,uint256,uint256,uint256,bool,uint8),bytes)[],bool)
        operatorAllowlist[0x5bf9264c] = true; // execPerpOps((uint8,bytes)[])
        operatorAllowlist[0xf769f0d3] = true; // increasePositionCollateral(uint256,uint256)
        operatorAllowlist[0x9c64b2b5] = true; // requestDecreasePositionCollateral(uint256)
        operatorAllowlist[0x4a1feb12] = true; // decreasePositionCollateral(uint256,uint256,bool)
        operatorAllowlist[0x1eebd35e] = true; // buyLiquidations((uint256,uint256,uint256,uint256)[],bool)
        operatorAllowlist[0xbad4a01f] = true; // depositCollateral(uint256)
        operatorAllowlist[0x7962f910] = true; // allowOrderForwarding(bool)
    }

    // ============ Fallback - Forwards calls to Exchange ============

    /// @notice Forwards any call to the Exchange contract
    /// @dev Owner can call anything; operator can only call allowlisted functions
    fallback() external {
        address _owner = owner();
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

    // ============ Owner Management ============

    /// @notice Update the operator address
    /// @dev Set to address(0) to disable operator access
    function setOperator(address newOperator) external onlyOwner {
        address oldOperator = operator;
        operator = newOperator;
        emit OperatorUpdated(oldOperator, newOperator);
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
        if (amount == 0) revert ZeroAmount();
        if (COLLATERAL_TOKEN.balanceOf(address(this)) < amount) revert InsufficientBalance();

        (bool success, bytes memory returnData) = EXCHANGE.call(abi.encodeWithSelector(CREATE_ACCOUNT, amount));
        if (!success) revert CallFailed(returnData);
        if (returnData.length < 32) revert InvalidReturnData();

        accountId = abi.decode(returnData, (uint256));
        emit AccountCreated(accountId);
    }

    // ============ Withdrawal ============

    /// @notice Withdraw collateral from the exchange to the owner
    /// @dev This explicit function ensures tokens are transferred to owner after withdrawal
    /// @param amount Amount to withdraw from the exchange
    function withdrawCollateral(uint256 amount) external onlyOwner {
        if (amount == 0) revert ZeroAmount();

        (bool success, bytes memory returnData) = EXCHANGE.call(abi.encodeWithSelector(WITHDRAW_COLLATERAL, amount));
        if (!success) revert CallFailed(returnData);

        // Transfer withdrawn tokens to owner
        uint256 balance = COLLATERAL_TOKEN.balanceOf(address(this));
        if (balance > 0) {
            COLLATERAL_TOKEN.safeTransfer(owner(), balance);
        }
    }

    /// @notice Transfer ERC20 tokens from this contract to owner
    /// @param token The token address to rescue
    /// @param amount Amount of tokens to transfer
    function rescueTokens(address token, uint256 amount) external onlyOwner {
        if (amount == 0) revert ZeroAmount();
        IERC20(token).safeTransfer(owner(), amount);
    }

    // ============ Approval Management ============

    /// @notice Update the Exchange approval amount for collateral token
    /// @dev Use 0 to revoke approval, type(uint256).max for infinite
    /// @param amount The new approval amount
    function setExchangeApproval(uint256 amount) external onlyOwner {
        COLLATERAL_TOKEN.forceApprove(EXCHANGE, amount);
        emit ExchangeApprovalUpdated(amount);
    }
}
