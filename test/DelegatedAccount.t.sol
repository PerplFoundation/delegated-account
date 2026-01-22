// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {DelegatedAccount} from "../src/DelegatedAccount.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IExchangeErrors} from "../interfaces/IExchangeErrors.sol";

/// @notice Mock Exchange that simulates the Perpl Exchange
contract MockExchange {
    uint256 public nextAccountId = 1;
    bool public shouldFail;
    bytes public failReason;

    function setShouldFail(bool _shouldFail, bytes memory _failReason) external {
        shouldFail = _shouldFail;
        failReason = _failReason;
    }

    function _revertWithReason() internal view {
        bytes memory reason = failReason;
        if (reason.length > 0) {
            assembly {
                revert(add(reason, 32), mload(reason))
            }
        } else {
            revert();
        }
    }

    // createAccount(uint256) - 0xcab13915
    function createAccount(uint256) external returns (uint256) {
        if (shouldFail) {
            _revertWithReason();
        }
        return nextAccountId++;
    }

    // withdrawCollateral(uint256) - 0x6112fe2e
    function withdrawCollateral(uint256) external view {
        if (shouldFail) {
            _revertWithReason();
        }
    }

    // depositCollateral(uint256) - 0xbad4a01f
    function depositCollateral(uint256) external view {
        if (shouldFail) {
            _revertWithReason();
        }
    }

    // execOrder(...) - 0x6b69ebbe (allowlisted for operator)
    function execOrder(bytes calldata) external view returns (bool) {
        if (shouldFail) {
            _revertWithReason();
        }
        return true;
    }

    // Fallback to accept any call
    fallback() external payable {
        if (shouldFail) {
            _revertWithReason();
        }
    }

    receive() external payable {}
}

// ============================================================================
// Base Test Setup
// ============================================================================

abstract contract Base_Test is Test {
    DelegatedAccount public delegatedAccount;
    DelegatedAccount public implementation;
    MockExchange public exchange;
    ERC20Mock public token;

    address public owner;
    address public operator;
    address public user;
    address public exchangeAddr;

    uint256 public constant INITIAL_BALANCE = 1_000_000e18;
    uint256 public constant DEPOSIT_AMOUNT = 100_000e18;

    // Selectors
    bytes4 constant CREATE_ACCOUNT = 0xcab13915;
    bytes4 constant WITHDRAW_COLLATERAL = 0x6112fe2e;
    bytes4 constant DEPOSIT_COLLATERAL = 0xbad4a01f;
    bytes4 constant EXEC_ORDER = 0x6b69ebbe;
    bytes4 constant XFER_ACCT_TO_PROTOCOL = 0x61bd6f44;

    function setUp() public virtual {
        owner = makeAddr("owner");
        operator = makeAddr("operator");
        user = makeAddr("user");

        exchange = new MockExchange();
        exchangeAddr = address(exchange);

        token = new ERC20Mock();

        // Deploy implementation
        implementation = new DelegatedAccount();

        // Deploy proxy with initialization
        bytes memory initData =
            abi.encodeWithSelector(DelegatedAccount.initialize.selector, owner, operator, exchangeAddr, address(token));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        delegatedAccount = DelegatedAccount(payable(address(proxy)));

        // Fund the delegated account and owner
        token.mint(address(delegatedAccount), INITIAL_BALANCE);
        token.mint(owner, INITIAL_BALANCE);
    }

    // ============ Helpers ============

    function _createAccount(uint256 amount) internal {
        vm.startPrank(owner);
        delegatedAccount.createAccount(amount);
        vm.stopPrank();
    }

    function _encodeDepositCollateral(uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(DEPOSIT_COLLATERAL, amount);
    }

    function _encodeExecOrder(bytes memory data) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(EXEC_ORDER, data);
    }

    function _encodeWithdrawCollateral(uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(WITHDRAW_COLLATERAL, amount);
    }

    function _encodeXferAcctToProtocol(uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(XFER_ACCT_TO_PROTOCOL, amount);
    }

    /// @notice Call the delegated account's fallback with specific calldata
    function _callFallback(address caller, bytes memory data) internal returns (bool, bytes memory) {
        vm.prank(caller);
        return address(delegatedAccount).call(data);
    }
}

// ============================================================================
// Initialize Tests
// ============================================================================

contract Initialize_Test is Base_Test {
    function test_RevertWhen_OwnerIsZeroAddress() external {
        DelegatedAccount impl = new DelegatedAccount();
        bytes memory initData =
            abi.encodeWithSelector(DelegatedAccount.initialize.selector, address(0), operator, exchangeAddr, address(token));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new ERC1967Proxy(address(impl), initData);
    }

    function test_RevertWhen_ExchangeIsZeroAddress() external {
        DelegatedAccount impl = new DelegatedAccount();
        bytes memory initData =
            abi.encodeWithSelector(DelegatedAccount.initialize.selector, owner, operator, address(0), address(token));
        vm.expectRevert(DelegatedAccount.ZeroAddress.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function test_RevertWhen_CollateralTokenIsZeroAddress() external {
        DelegatedAccount impl = new DelegatedAccount();
        bytes memory initData =
            abi.encodeWithSelector(DelegatedAccount.initialize.selector, owner, operator, exchangeAddr, address(0));
        vm.expectRevert(DelegatedAccount.ZeroAddress.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function test_RevertWhen_AlreadyInitialized() external {
        // Try to initialize again
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        delegatedAccount.initialize(owner, operator, exchangeAddr, address(token));
    }

    function test_WhenOperatorIsZeroAddress() external {
        // it should allow deployment (operator is optional)
        DelegatedAccount impl = new DelegatedAccount();
        bytes memory initData =
            abi.encodeWithSelector(DelegatedAccount.initialize.selector, owner, address(0), exchangeAddr, address(token));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        DelegatedAccount da = DelegatedAccount(payable(address(proxy)));
        assertEq(da.operator(), address(0));
    }

    function test_WhenAllParametersAreValid() external view {
        // it should set the owner.
        assertEq(delegatedAccount.owner(), owner);

        // it should set the operator.
        assertEq(delegatedAccount.operator(), operator);

        // it should set the exchange.
        assertEq(delegatedAccount.exchange(), exchangeAddr);

        // it should set the collateralToken.
        assertEq(address(delegatedAccount.collateralToken()), address(token));

        // it should give infinite approval to exchange.
        assertEq(token.allowance(address(delegatedAccount), exchangeAddr), type(uint256).max);

        // it should initialize operator allowlist with default selectors.
        assertTrue(delegatedAccount.operatorAllowlist(0x6b69ebbe)); // execOrder
        assertTrue(delegatedAccount.operatorAllowlist(0xaf3176da)); // execOrders
        assertTrue(delegatedAccount.operatorAllowlist(0x5bf9264c)); // execPerpOps
        assertTrue(delegatedAccount.operatorAllowlist(0xf769f0d3)); // increasePositionCollateral
        assertTrue(delegatedAccount.operatorAllowlist(0x9c64b2b5)); // requestDecreasePositionCollateral
        assertTrue(delegatedAccount.operatorAllowlist(0x4a1feb12)); // decreasePositionCollateral
        assertTrue(delegatedAccount.operatorAllowlist(0x1eebd35e)); // buyLiquidations
        assertTrue(delegatedAccount.operatorAllowlist(0xbad4a01f)); // depositCollateral
        assertTrue(delegatedAccount.operatorAllowlist(0x7962f910)); // allowOrderForwarding
    }
}

// ============================================================================
// Fallback Tests
// ============================================================================

contract Fallback_Test is Base_Test {
    function test_RevertWhen_CallerIsNotOwnerOrOperator() external {
        bytes memory data = _encodeExecOrder("");

        vm.prank(user);
        vm.expectRevert(DelegatedAccount.OnlyOwnerOrOperator.selector);
        (bool success,) = address(delegatedAccount).call(data);
        // The expectRevert catches the revert, so success will be true in test context
        // but we already verified the revert happened
        success; // silence unused variable warning
    }

    // ============ When Caller Is Owner ============

    function test_WhenCallerIsOwner_ExchangeCallFails() external {
        _createAccount(DEPOSIT_AMOUNT);
        exchange.setShouldFail(true, "");

        bytes memory data = _encodeDepositCollateral(DEPOSIT_AMOUNT);

        // it should bubble up the revert
        vm.prank(owner);
        (bool success,) = address(delegatedAccount).call(data);
        assertFalse(success);
    }

    function test_WhenCallerIsOwner_ExchangeCallSucceeds() external {
        _createAccount(DEPOSIT_AMOUNT);

        // Use allowOrderForwarding which goes through fallback (depositCollateral is now a direct function)
        bytes memory data = abi.encodeWithSelector(0x7962f910, true); // allowOrderForwarding(bool)

        // it should return the call result (infinite approval in constructor)
        vm.prank(owner);
        (bool success,) = address(delegatedAccount).call(data);
        assertTrue(success);
    }

    function test_WhenCallerIsOwner_CanCallNonAllowlistedSelector() external {
        _createAccount(DEPOSIT_AMOUNT);

        // Owner can call any selector, even non-allowlisted ones
        bytes memory data = _encodeXferAcctToProtocol(DEPOSIT_AMOUNT);

        vm.prank(owner);
        (bool success,) = address(delegatedAccount).call(data);
        assertTrue(success);
    }

    // ============ When Caller Is Operator ============

    function test_RevertWhen_CallerIsOperator_AccountDoesNotExist() external {
        bytes memory data = _encodeExecOrder("");

        vm.prank(operator);
        vm.expectRevert(DelegatedAccount.AccountNotCreated.selector);
        (bool success,) = address(delegatedAccount).call(data);
        success;
    }

    function test_RevertWhen_CallerIsOperator_CalldataLessThan4Bytes() external {
        _createAccount(DEPOSIT_AMOUNT);

        // it should revert with SelectorNotAllowed
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(DelegatedAccount.SelectorNotAllowed.selector, bytes4(0)));
        (bool success,) = address(delegatedAccount).call(hex"112233"); // 3 bytes
        success;
    }

    function test_RevertWhen_CallerIsOperator_SelectorNotAllowlisted() external {
        _createAccount(DEPOSIT_AMOUNT);

        bytes memory data = _encodeWithdrawCollateral(DEPOSIT_AMOUNT);

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(DelegatedAccount.SelectorNotAllowed.selector, WITHDRAW_COLLATERAL));
        (bool success,) = address(delegatedAccount).call(data);
        success;
    }

    function test_RevertWhen_CallerIsOperator_SelectorIsXferAcctToProtocol() external {
        _createAccount(DEPOSIT_AMOUNT);

        bytes memory data = _encodeXferAcctToProtocol(DEPOSIT_AMOUNT);

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(DelegatedAccount.SelectorNotAllowed.selector, XFER_ACCT_TO_PROTOCOL));
        (bool success,) = address(delegatedAccount).call(data);
        success;
    }

    function test_WhenCallerIsOperator_SelectorAllowlisted_ExchangeCallFails() external {
        _createAccount(DEPOSIT_AMOUNT);
        exchange.setShouldFail(true, "");

        bytes memory data = _encodeExecOrder("");

        // it should bubble up the revert
        vm.prank(operator);
        (bool success,) = address(delegatedAccount).call(data);
        assertFalse(success);
    }

    function test_WhenCallerIsOperator_SelectorAllowlisted_ExchangeCallSucceeds() external {
        _createAccount(DEPOSIT_AMOUNT);

        // Use depositCollateral which is allowlisted and the mock supports
        bytes memory data = _encodeDepositCollateral(DEPOSIT_AMOUNT);

        // it should return the call result (infinite approval in constructor)
        vm.prank(operator);
        (bool success,) = address(delegatedAccount).call(data);
        assertTrue(success);
    }
}

// ============================================================================
// TransferOwnership Tests
// ============================================================================

contract TransferOwnership_Test is Base_Test {
    function test_RevertWhen_CallerIsNotOwner() external {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        delegatedAccount.transferOwnership(user);
    }

    function test_WhenNewOwnerIsValid_TwoStepTransfer() external {
        address newOwner = makeAddr("newOwner");

        // Step 1: Transfer ownership (sets pending owner)
        vm.prank(owner);
        delegatedAccount.transferOwnership(newOwner);

        // Owner should still be the original owner
        assertEq(delegatedAccount.owner(), owner);
        // Pending owner should be set
        assertEq(delegatedAccount.pendingOwner(), newOwner);

        // Step 2: New owner accepts ownership
        vm.prank(newOwner);
        delegatedAccount.acceptOwnership();

        // Now ownership is transferred
        assertEq(delegatedAccount.owner(), newOwner);
        assertEq(delegatedAccount.pendingOwner(), address(0));
    }

    function test_RevertWhen_NonPendingOwnerAccepts() external {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        delegatedAccount.transferOwnership(newOwner);

        // Random user tries to accept
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        delegatedAccount.acceptOwnership();
    }
}

// ============================================================================
// SetOperator Tests
// ============================================================================

contract SetOperator_Test is Base_Test {
    function test_RevertWhen_CallerIsNotOwner() external {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        delegatedAccount.setOperator(user);
    }

    function test_WhenCallerIsOwner() external {
        address newOperator = makeAddr("newOperator");

        // it should emit OperatorUpdated event.
        vm.expectEmit(true, true, false, false);
        emit DelegatedAccount.OperatorUpdated(operator, newOperator);

        vm.prank(owner);
        delegatedAccount.setOperator(newOperator);

        // it should update operator.
        assertEq(delegatedAccount.operator(), newOperator);
    }

    function test_WhenSettingOperatorToZeroAddress() external {
        vm.prank(owner);
        delegatedAccount.setOperator(address(0));
        assertEq(delegatedAccount.operator(), address(0));
    }
}

// ============================================================================
// SetOperatorAllowlist Tests
// ============================================================================

contract SetOperatorAllowlist_Test is Base_Test {
    function test_RevertWhen_CallerIsNotOwner() external {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        delegatedAccount.setOperatorAllowlist(0x12345678, true);
    }

    modifier whenCallerIsOwner() {
        vm.startPrank(owner);
        _;
        vm.stopPrank();
    }

    function test_WhenAddingSelector() external whenCallerIsOwner {
        bytes4 selector = 0x12345678;
        assertFalse(delegatedAccount.operatorAllowlist(selector));

        // it should emit OperatorAllowlistUpdated event.
        vm.expectEmit(true, false, false, true);
        emit DelegatedAccount.OperatorAllowlistUpdated(selector, true);

        delegatedAccount.setOperatorAllowlist(selector, true);

        // it should update allowlist.
        assertTrue(delegatedAccount.operatorAllowlist(selector));
    }

    function test_WhenRemovingSelector() external whenCallerIsOwner {
        // First verify a default selector is allowed
        bytes4 selector = 0x6b69ebbe; // execOrder
        assertTrue(delegatedAccount.operatorAllowlist(selector));

        // it should emit OperatorAllowlistUpdated event.
        vm.expectEmit(true, false, false, true);
        emit DelegatedAccount.OperatorAllowlistUpdated(selector, false);

        delegatedAccount.setOperatorAllowlist(selector, false);

        // it should update allowlist.
        assertFalse(delegatedAccount.operatorAllowlist(selector));
    }
}

// ============================================================================
// CreateAccount Tests
// ============================================================================

contract CreateAccount_Test is Base_Test {
    function test_RevertWhen_CallerIsNotOwner() external {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        delegatedAccount.createAccount(DEPOSIT_AMOUNT);
    }

    function test_RevertWhen_AccountAlreadyExists() external {
        _createAccount(DEPOSIT_AMOUNT);

        vm.prank(owner);
        vm.expectRevert(DelegatedAccount.AccountAlreadyCreated.selector);
        delegatedAccount.createAccount(DEPOSIT_AMOUNT);
    }

    function test_RevertWhen_ExchangeCallFails() external {
        exchange.setShouldFail(true, "");

        // Error bubbles up directly from Exchange (empty revert in this case)
        vm.prank(owner);
        vm.expectRevert();
        delegatedAccount.createAccount(DEPOSIT_AMOUNT);
    }

    function test_RevertWhen_ExchangeCallFails_BubblesUpExchangeError() external {
        // Set up Exchange to revert with InsufficentAmountToOpenAccount error
        bytes memory errorData = abi.encodeWithSelector(
            IExchangeErrors.InsufficentAmountToOpenAccount.selector, address(delegatedAccount), DEPOSIT_AMOUNT
        );
        exchange.setShouldFail(true, errorData);

        // Error should bubble up directly from Exchange
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IExchangeErrors.InsufficentAmountToOpenAccount.selector, address(delegatedAccount), DEPOSIT_AMOUNT
            )
        );
        delegatedAccount.createAccount(DEPOSIT_AMOUNT);
    }

    function test_WhenAccountDoesNotExist() external {
        // it should emit AccountCreated event.
        vm.expectEmit(true, false, false, false);
        emit DelegatedAccount.AccountCreated(1);

        vm.prank(owner);
        delegatedAccount.createAccount(DEPOSIT_AMOUNT);

        // it should store the accountId.
        assertEq(delegatedAccount.accountId(), 1);
    }
}

// ============================================================================
// WithdrawCollateral Tests
// ============================================================================

contract WithdrawCollateral_Test is Base_Test {
    function test_RevertWhen_CallerIsNotOwner() external {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        delegatedAccount.withdrawCollateral(DEPOSIT_AMOUNT);
    }

    function test_RevertWhen_ExchangeCallFails() external {
        exchange.setShouldFail(true, "");

        // Error bubbles up directly from Exchange (empty revert in this case)
        vm.prank(owner);
        vm.expectRevert();
        delegatedAccount.withdrawCollateral(DEPOSIT_AMOUNT);
    }

    function test_WhenExchangeCallSucceeds() external {
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 contractBalance = token.balanceOf(address(delegatedAccount));

        vm.prank(owner);
        delegatedAccount.withdrawCollateral(DEPOSIT_AMOUNT);

        // it should transfer tokens to owner.
        assertEq(token.balanceOf(owner), ownerBalanceBefore + contractBalance);
        assertEq(token.balanceOf(address(delegatedAccount)), 0);
    }
}

// ============================================================================
// RescueTokens Tests
// ============================================================================

contract RescueTokens_Test is Base_Test {
    function test_RevertWhen_CallerIsNotOwner() external {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        delegatedAccount.rescueTokens(address(token), DEPOSIT_AMOUNT);
    }

    function test_WhenCallerIsOwner() external {
        uint256 rescueAmount = 50_000e18;
        uint256 ownerBalanceBefore = token.balanceOf(owner);

        vm.prank(owner);
        delegatedAccount.rescueTokens(address(token), rescueAmount);

        // it should transfer tokens to owner.
        assertEq(token.balanceOf(owner), ownerBalanceBefore + rescueAmount);
    }
}

// ============================================================================
// IsOperatorAllowed Tests
// ============================================================================

contract IsOperatorAllowed_Test is Base_Test {
    function test_WhenSelectorIsInDefaultAllowlist() external view {
        // Default allowlisted selectors should return true
        assertTrue(delegatedAccount.operatorAllowlist(0x6b69ebbe)); // execOrder
        assertTrue(delegatedAccount.operatorAllowlist(0xaf3176da)); // execOrders
        assertTrue(delegatedAccount.operatorAllowlist(0x5bf9264c)); // execPerpOps
        assertTrue(delegatedAccount.operatorAllowlist(0xf769f0d3)); // increasePositionCollateral
        assertTrue(delegatedAccount.operatorAllowlist(0x9c64b2b5)); // requestDecreasePositionCollateral
        assertTrue(delegatedAccount.operatorAllowlist(0x4a1feb12)); // decreasePositionCollateral
        assertTrue(delegatedAccount.operatorAllowlist(0x1eebd35e)); // buyLiquidations
        assertTrue(delegatedAccount.operatorAllowlist(0xbad4a01f)); // depositCollateral
        assertTrue(delegatedAccount.operatorAllowlist(0x7962f910)); // allowOrderForwarding
    }

    function test_WhenSelectorIsNotAllowlisted() external view {
        // Non-allowlisted selectors should return false
        assertFalse(delegatedAccount.operatorAllowlist(WITHDRAW_COLLATERAL));
        assertFalse(delegatedAccount.operatorAllowlist(XFER_ACCT_TO_PROTOCOL));
        assertFalse(delegatedAccount.operatorAllowlist(0x12345678));
    }
}

// ============================================================================
// Upgrade Tests
// ============================================================================

/// @notice Mock V2 implementation for testing upgrades
contract DelegatedAccountV2 is DelegatedAccount {
    uint256 public newVariable;

    function setNewVariable(uint256 _value) external {
        newVariable = _value;
    }

    function version() external pure returns (uint256) {
        return 2;
    }
}

contract Upgrade_Test is Base_Test {
    function test_RevertWhen_CallerIsNotOwner() external {
        DelegatedAccountV2 newImplementation = new DelegatedAccountV2();

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        delegatedAccount.upgradeToAndCall(address(newImplementation), "");
    }

    function test_WhenCallerIsOwner_CanUpgrade() external {
        DelegatedAccountV2 newImplementation = new DelegatedAccountV2();

        vm.prank(owner);
        delegatedAccount.upgradeToAndCall(address(newImplementation), "");

        // Verify the upgrade by calling the new version function
        DelegatedAccountV2 upgraded = DelegatedAccountV2(payable(address(delegatedAccount)));
        assertEq(upgraded.version(), 2);
    }

    function test_WhenUpgrading_StateIsPreserved() external {
        // Set up some state before upgrade
        _createAccount(DEPOSIT_AMOUNT);

        address newOperator = makeAddr("newOperator");
        vm.prank(owner);
        delegatedAccount.setOperator(newOperator);

        bytes4 customSelector = 0x12345678;
        vm.prank(owner);
        delegatedAccount.setOperatorAllowlist(customSelector, true);

        // Store state before upgrade
        address ownerBefore = delegatedAccount.owner();
        address operatorBefore = delegatedAccount.operator();
        address exchangeBefore = delegatedAccount.exchange();
        address collateralTokenBefore = address(delegatedAccount.collateralToken());
        uint256 accountIdBefore = delegatedAccount.accountId();
        bool customSelectorAllowed = delegatedAccount.operatorAllowlist(customSelector);

        // Upgrade
        DelegatedAccountV2 newImplementation = new DelegatedAccountV2();
        vm.prank(owner);
        delegatedAccount.upgradeToAndCall(address(newImplementation), "");

        // Verify state is preserved
        DelegatedAccountV2 upgraded = DelegatedAccountV2(payable(address(delegatedAccount)));
        assertEq(upgraded.owner(), ownerBefore);
        assertEq(upgraded.operator(), operatorBefore);
        assertEq(upgraded.exchange(), exchangeBefore);
        assertEq(address(upgraded.collateralToken()), collateralTokenBefore);
        assertEq(upgraded.accountId(), accountIdBefore);
        assertTrue(upgraded.operatorAllowlist(customSelector) == customSelectorAllowed);

        // Verify new functionality works
        upgraded.setNewVariable(42);
        assertEq(upgraded.newVariable(), 42);
    }

    function test_WhenUpgrading_CanUpgradeWithInitData() external {
        DelegatedAccountV2 newImplementation = new DelegatedAccountV2();

        // Upgrade and call setNewVariable in one transaction
        bytes memory initData = abi.encodeWithSelector(DelegatedAccountV2.setNewVariable.selector, 123);

        vm.prank(owner);
        delegatedAccount.upgradeToAndCall(address(newImplementation), initData);

        DelegatedAccountV2 upgraded = DelegatedAccountV2(payable(address(delegatedAccount)));
        assertEq(upgraded.newVariable(), 123);
        assertEq(upgraded.version(), 2);
    }

    function test_RevertWhen_UpgradingToNonUUPSImplementation() external {
        // Try to upgrade to a non-UUPS contract (the mock exchange)
        vm.prank(owner);
        vm.expectRevert();
        delegatedAccount.upgradeToAndCall(address(exchange), "");
    }
}
