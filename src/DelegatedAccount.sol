// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {IExchange} from "../interfaces/IExchange.sol";

/// @title DelegatedAccount
/// @notice A proxy-style contract that forwards calls to the Perpl Exchange.
///         Call this contract with the Exchange's ABI - calls are automatically forwarded.
///         - Owner (MM): Can call any Exchange function
///         - Operator (hot wallet): Can only call allowlisted functions
/// @dev Deploy behind a BeaconProxy via DelegatedAccountFactory.
contract DelegatedAccount is Initializable, Ownable2StepUpgradeable {
    using SafeERC20 for IERC20;

    // ============ Errors ============
    error OnlyOwnerOrOperator();
    error SelectorNotAllowed(bytes4 selector);
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error InvalidReturnData();
    error AccountAlreadyCreated();
    error AccountNotCreated();

    // ============ Events ============
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);
    event AccountCreated(uint256 indexed accountId);
    event OperatorAllowlistUpdated(bytes4 indexed selector, bool allowed);
    event ExchangeApprovalUpdated(uint256 amount);

    // ============ State ============
    mapping(address => bool) public operators;
    address public exchange;
    IERC20 public collateralToken;
    uint256 public accountId;

    // Operator allowlist - only these selectors can be called by operator
    mapping(bytes4 => bool) public operatorAllowlist;

    // ============ Function Selectors ============
    bytes4 private constant WITHDRAW_COLLATERAL = IExchange.withdrawCollateral.selector;
    bytes4 private constant CREATE_ACCOUNT = IExchange.createAccount.selector;

    // ============ Storage Gap ============
    /// @dev Reserved storage space to allow for layout changes in future upgrades
    uint256[45] private __gap;

    // ============ Constructor ============
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ============ Initializer ============
    /// @notice Initializes the contract (replaces constructor for upgradeable pattern)
    /// @param _owner The owner address (MM)
    /// @param _operator The operator address (hot wallet)
    /// @param _exchange The Perpl Exchange address (collateral token is fetched from it)
    function initialize(address _owner, address _operator, address _exchange) external initializer {
        if (_exchange == address(0)) {
            revert ZeroAddress();
        }

        __Ownable_init(_owner);

        if (_operator != address(0)) {
            operators[_operator] = true;
        }
        exchange = _exchange;

        // Fetch collateral token from the exchange (also validates exchange address)
        (,,,, address _collateralToken,) = IExchange(_exchange).getExchangeInfo();
        collateralToken = IERC20(_collateralToken);

        // Give Exchange infinite approval (trusted contract)
        IERC20(_collateralToken).forceApprove(_exchange, type(uint256).max);

        // Initialize operator allowlist with Exchange function selectors
        operatorAllowlist[IExchange.execOrder.selector] = true;
        operatorAllowlist[IExchange.execOrders.selector] = true;
        operatorAllowlist[IExchange.increasePositionCollateral.selector] = true;
        operatorAllowlist[IExchange.requestDecreasePositionCollateral.selector] = true;
        operatorAllowlist[IExchange.decreasePositionCollateral.selector] = true;
        operatorAllowlist[IExchange.buyLiquidations.selector] = true;
        operatorAllowlist[IExchange.depositCollateral.selector] = true;
        operatorAllowlist[IExchange.allowOrderForwarding.selector] = true;
    }

    // ============ Fallback - Forwards calls to Exchange ============

    /// @notice Forwards any call to the Exchange contract
    /// @dev Owner can call anything; operators can only call allowlisted functions
    fallback() external {
        address _owner = owner();
        address _exchange = exchange;
        bool _isOperator = operators[msg.sender];

        // Must be owner or operator
        if (msg.sender != _owner && !_isOperator) {
            revert OnlyOwnerOrOperator();
        }

        // Check allowlist for operators
        if (_isOperator) {
            if (accountId == 0) revert AccountNotCreated();
            if (msg.data.length < 4) revert SelectorNotAllowed(bytes4(0));
            bytes4 selector = bytes4(msg.data[:4]);
            if (!operatorAllowlist[selector]) {
                revert SelectorNotAllowed(selector);
            }
        }

        // Forward call to Exchange
        (bool success, bytes memory returnData) = _exchange.call(msg.data);

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

    /// @notice Add an operator
    /// @param _operator The address to add as operator
    function addOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        operators[_operator] = true;
        emit OperatorAdded(_operator);
    }

    /// @notice Remove an operator
    /// @param _operator The address to remove as operator
    function removeOperator(address _operator) external onlyOwner {
        operators[_operator] = false;
        emit OperatorRemoved(_operator);
    }

    /// @notice Check if an address is an operator
    /// @param _operator The address to check
    /// @return True if the address is an operator
    function isOperator(address _operator) external view returns (bool) {
        return operators[_operator];
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
    /// @dev This wrapper is needed to store the returned accountId in contract state.
    ///      Cannot use fallback because we need to capture and decode the return value.
    ///      Contract must have tokens before calling (infinite approval to Exchange set in initializer).
    /// @param amount Initial deposit amount
    function createAccount(uint256 amount) external onlyOwner {
        if (accountId != 0) revert AccountAlreadyCreated();
        if (amount == 0) revert ZeroAmount();
        if (collateralToken.balanceOf(address(this)) < amount) revert InsufficientBalance();

        (bool success, bytes memory returnData) = exchange.call(abi.encodeWithSelector(CREATE_ACCOUNT, amount));
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }
        if (returnData.length < 32) revert InvalidReturnData();

        accountId = abi.decode(returnData, (uint256));
        emit AccountCreated(accountId);
    }

    // ============ Withdrawal ============

    /// @notice Withdraw collateral from the exchange to the owner
    /// @dev This wrapper is needed to transfer tokens to owner after Exchange withdrawal.
    ///      Cannot use fallback because Exchange.withdrawCollateral sends tokens to msg.sender
    ///      (this contract), requiring an additional transfer to the actual owner.
    /// @param amount Amount to withdraw from the exchange
    function withdrawCollateral(uint256 amount) external onlyOwner {
        if (amount == 0) revert ZeroAmount();

        (bool success, bytes memory returnData) = exchange.call(abi.encodeWithSelector(WITHDRAW_COLLATERAL, amount));
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }

        // Transfer withdrawn tokens to owner
        uint256 balance = collateralToken.balanceOf(address(this));
        if (balance > 0) {
            collateralToken.safeTransfer(owner(), balance);
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
        collateralToken.forceApprove(exchange, amount);
        emit ExchangeApprovalUpdated(amount);
    }
}
