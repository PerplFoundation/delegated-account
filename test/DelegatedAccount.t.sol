// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {DelegatedAccount} from "../src/DelegatedAccount.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IExchangeErrors} from "../interfaces/IExchangeErrors.sol";
import {DelegatedAccountFactory} from "../src/DelegatedAccountFactory.sol";

/// @notice Mock Exchange that simulates the Perpl Exchange
contract MockExchange {
    uint256 public nextAccountId = 1;
    bool public shouldFail;
    bytes public failReason;
    address public collateralToken;

    constructor(address _collateralToken) {
        collateralToken = _collateralToken;
    }

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

    // getExchangeInfo() - returns exchange info including collateral token
    function getExchangeInfo() external view returns (uint256, uint256, uint256, uint256, address, address) {
        return (0, 0, 0, 18, collateralToken, address(0));
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
    UpgradeableBeacon public beacon;
    MockExchange public exchange;
    ERC20Mock public token;

    address public owner;
    address public operator;
    address public user;
    address public exchangeAddr;
    address public beaconOwner;

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
        beaconOwner = makeAddr("beaconOwner");

        token = new ERC20Mock();

        exchange = new MockExchange(address(token));
        exchangeAddr = address(exchange);

        // Deploy implementation and beacon
        implementation = new DelegatedAccount();
        beacon = new UpgradeableBeacon(address(implementation), beaconOwner);

        // Deploy proxy with initialization
        bytes memory initData =
            abi.encodeWithSelector(DelegatedAccount.initialize.selector, owner, operator, exchangeAddr);
        BeaconProxy proxy = new BeaconProxy(address(beacon), initData);
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
        bytes memory initData =
            abi.encodeWithSelector(DelegatedAccount.initialize.selector, address(0), operator, exchangeAddr);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new BeaconProxy(address(beacon), initData);
    }

    function test_RevertWhen_ExchangeIsZeroAddress() external {
        bytes memory initData =
            abi.encodeWithSelector(DelegatedAccount.initialize.selector, owner, operator, address(0));
        vm.expectRevert(DelegatedAccount.ZeroAddress.selector);
        new BeaconProxy(address(beacon), initData);
    }

    function test_RevertWhen_AlreadyInitialized() external {
        // Try to initialize again
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        delegatedAccount.initialize(owner, operator, exchangeAddr);
    }

    function test_WhenOperatorIsZeroAddress() external {
        // it should allow deployment (operator is optional)
        bytes memory initData =
            abi.encodeWithSelector(DelegatedAccount.initialize.selector, owner, address(0), exchangeAddr);
        BeaconProxy proxy = new BeaconProxy(address(beacon), initData);
        DelegatedAccount da = DelegatedAccount(payable(address(proxy)));
        assertFalse(da.isOperator(address(0)));
    }

    function test_WhenAllParametersAreValid() external view {
        // it should set the owner.
        assertEq(delegatedAccount.owner(), owner);

        // it should set the operator.
        assertTrue(delegatedAccount.isOperator(operator));

        // it should set the exchange.
        assertEq(delegatedAccount.exchange(), exchangeAddr);

        // it should set the collateralToken.
        assertEq(address(delegatedAccount.collateralToken()), address(token));

        // it should give infinite approval to exchange.
        assertEq(token.allowance(address(delegatedAccount), exchangeAddr), type(uint256).max);

        // it should initialize operator allowlist with default selectors.
        assertTrue(delegatedAccount.operatorAllowlist(0x6b69ebbe)); // execOrder
        assertTrue(delegatedAccount.operatorAllowlist(0xaf3176da)); // execOrders
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
// Operator Management Tests
// ============================================================================

contract OperatorManagement_Test is Base_Test {
    function test_AddOperator_RevertWhen_CallerIsNotOwner() external {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        delegatedAccount.addOperator(user);
    }

    function test_AddOperator_RevertWhen_ZeroAddress() external {
        vm.prank(owner);
        vm.expectRevert(DelegatedAccount.ZeroAddress.selector);
        delegatedAccount.addOperator(address(0));
    }

    function test_AddOperator_WhenCallerIsOwner() external {
        address newOperator = makeAddr("newOperator");

        // it should emit OperatorAdded event.
        vm.expectEmit(true, false, false, false);
        emit DelegatedAccount.OperatorAdded(newOperator);

        vm.prank(owner);
        delegatedAccount.addOperator(newOperator);

        // it should add operator.
        assertTrue(delegatedAccount.isOperator(newOperator));
    }

    function test_RemoveOperator_RevertWhen_CallerIsNotOwner() external {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        delegatedAccount.removeOperator(operator);
    }

    function test_RemoveOperator_WhenCallerIsOwner() external {
        // it should emit OperatorRemoved event.
        vm.expectEmit(true, false, false, false);
        emit DelegatedAccount.OperatorRemoved(operator);

        vm.prank(owner);
        delegatedAccount.removeOperator(operator);

        // it should remove operator.
        assertFalse(delegatedAccount.isOperator(operator));
    }

    function test_MultipleOperators() external {
        address operator2 = makeAddr("operator2");
        address operator3 = makeAddr("operator3");

        // Add multiple operators
        vm.startPrank(owner);
        delegatedAccount.addOperator(operator2);
        delegatedAccount.addOperator(operator3);
        vm.stopPrank();

        // Verify all operators are set
        assertTrue(delegatedAccount.isOperator(operator));
        assertTrue(delegatedAccount.isOperator(operator2));
        assertTrue(delegatedAccount.isOperator(operator3));

        // Remove one operator
        vm.prank(owner);
        delegatedAccount.removeOperator(operator2);

        // Verify operator2 is removed but others remain
        assertTrue(delegatedAccount.isOperator(operator));
        assertFalse(delegatedAccount.isOperator(operator2));
        assertTrue(delegatedAccount.isOperator(operator3));
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
    function test_RevertWhen_CallerIsNotBeaconOwner() external {
        DelegatedAccountV2 newImplementation = new DelegatedAccountV2();

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        beacon.upgradeTo(address(newImplementation));
    }

    function test_WhenCallerIsBeaconOwner_CanUpgrade() external {
        DelegatedAccountV2 newImplementation = new DelegatedAccountV2();

        vm.prank(beaconOwner);
        beacon.upgradeTo(address(newImplementation));

        // Verify the upgrade by calling the new version function
        DelegatedAccountV2 upgraded = DelegatedAccountV2(payable(address(delegatedAccount)));
        assertEq(upgraded.version(), 2);
    }

    function test_WhenUpgrading_StateIsPreserved() external {
        // Set up some state before upgrade
        _createAccount(DEPOSIT_AMOUNT);

        address newOperator = makeAddr("newOperator");
        vm.prank(owner);
        delegatedAccount.addOperator(newOperator);

        bytes4 customSelector = 0x12345678;
        vm.prank(owner);
        delegatedAccount.setOperatorAllowlist(customSelector, true);

        // Store state before upgrade
        address ownerBefore = delegatedAccount.owner();
        bool operatorBefore = delegatedAccount.isOperator(operator);
        bool newOperatorBefore = delegatedAccount.isOperator(newOperator);
        address exchangeBefore = delegatedAccount.exchange();
        address collateralTokenBefore = address(delegatedAccount.collateralToken());
        uint256 accountIdBefore = delegatedAccount.accountId();
        bool customSelectorAllowed = delegatedAccount.operatorAllowlist(customSelector);

        // Upgrade via beacon
        DelegatedAccountV2 newImplementation = new DelegatedAccountV2();
        vm.prank(beaconOwner);
        beacon.upgradeTo(address(newImplementation));

        // Verify state is preserved
        DelegatedAccountV2 upgraded = DelegatedAccountV2(payable(address(delegatedAccount)));
        assertEq(upgraded.owner(), ownerBefore);
        assertEq(upgraded.isOperator(operator), operatorBefore);
        assertEq(upgraded.isOperator(newOperator), newOperatorBefore);
        assertEq(upgraded.exchange(), exchangeBefore);
        assertEq(address(upgraded.collateralToken()), collateralTokenBefore);
        assertEq(upgraded.accountId(), accountIdBefore);
        assertTrue(upgraded.operatorAllowlist(customSelector) == customSelectorAllowed);

        // Verify new functionality works
        upgraded.setNewVariable(42);
        assertEq(upgraded.newVariable(), 42);
    }

    function test_WhenUpgrading_AllProxiesAreUpgraded() external {
        // Deploy a second proxy behind the same beacon
        bytes memory initData =
            abi.encodeWithSelector(DelegatedAccount.initialize.selector, owner, operator, exchangeAddr);
        BeaconProxy proxy2 = new BeaconProxy(address(beacon), initData);
        DelegatedAccount da2 = DelegatedAccount(payable(address(proxy2)));

        // Upgrade beacon
        DelegatedAccountV2 newImplementation = new DelegatedAccountV2();
        vm.prank(beaconOwner);
        beacon.upgradeTo(address(newImplementation));

        // Both proxies should see the new implementation
        assertEq(DelegatedAccountV2(payable(address(delegatedAccount))).version(), 2);
        assertEq(DelegatedAccountV2(payable(address(da2))).version(), 2);
    }
}

// ============================================================================
// Factory Tests
// ============================================================================

contract Factory_Test is Test {
    DelegatedAccountFactory public factory;
    MockExchange public exchange;
    ERC20Mock public token;

    address public owner;
    uint256 public ownerKey;
    address public operator;
    address public beaconOwner;

    function setUp() public {
        (owner, ownerKey) = makeAddrAndKey("owner");
        operator = makeAddr("operator");
        beaconOwner = makeAddr("beaconOwner");

        token = new ERC20Mock();
        exchange = new MockExchange(address(token));

        DelegatedAccount implementation = new DelegatedAccount();
        factory = new DelegatedAccountFactory(address(implementation), beaconOwner);
    }

    function _signCreate(address _owner, address _operator, address _exchange, uint256 _deadline, uint256 _privateKey)
        internal
        view
        returns (bytes memory)
    {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("DelegatedAccountFactory"),
                keccak256("1"),
                block.chainid,
                address(factory)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(factory.CREATE_TYPEHASH(), _owner, _operator, _exchange, factory.nonces(_owner), _deadline)
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function test_RevertWhen_ImplementationIsZeroAddress() external {
        vm.expectRevert(DelegatedAccountFactory.ZeroAddress.selector);
        new DelegatedAccountFactory(address(0), beaconOwner);
    }

    function test_RevertWhen_BeaconOwnerIsZeroAddress() external {
        DelegatedAccount impl = new DelegatedAccount();
        vm.expectRevert(DelegatedAccountFactory.ZeroAddress.selector);
        new DelegatedAccountFactory(address(impl), address(0));
    }

    function test_Create_DeploysWorkingDelegatedAccount() external {
        vm.prank(owner);
        address proxy = factory.create(owner, operator, address(exchange));

        DelegatedAccount da = DelegatedAccount(payable(proxy));
        assertEq(da.owner(), owner);
        assertTrue(da.isOperator(operator));
        assertEq(da.exchange(), address(exchange));
        assertEq(address(da.collateralToken()), address(token));
    }

    function test_Create_EmitsEvent() external {
        vm.expectEmit(false, true, true, false);
        emit DelegatedAccountFactory.DelegatedAccountCreated(address(0), owner, operator);

        vm.prank(owner);
        factory.create(owner, operator, address(exchange));
    }

    function test_Create_RevertsIfNotOwner() external {
        address anyone = makeAddr("anyone");
        vm.prank(anyone);
        vm.expectRevert(DelegatedAccountFactory.Unauthorized.selector);
        factory.create(owner, operator, address(exchange));
    }

    function test_CreateWithSignature_DeploysWorkingDelegatedAccount() external {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _signCreate(owner, operator, address(exchange), deadline, ownerKey);

        address proxy = factory.createWithSignature(owner, operator, address(exchange), deadline, sig);

        DelegatedAccount da = DelegatedAccount(payable(proxy));
        assertEq(da.owner(), owner);
        assertTrue(da.isOperator(operator));
        assertEq(da.exchange(), address(exchange));
        assertEq(address(da.collateralToken()), address(token));
    }

    function test_CreateWithSignature_EmitsEvent() external {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _signCreate(owner, operator, address(exchange), deadline, ownerKey);

        vm.expectEmit(false, true, true, false);
        emit DelegatedAccountFactory.DelegatedAccountCreated(address(0), owner, operator);

        factory.createWithSignature(owner, operator, address(exchange), deadline, sig);
    }

    function test_CreateWithSignature_IncrementsNonce() external {
        uint256 deadline = block.timestamp + 1 hours;
        assertEq(factory.nonces(owner), 0);

        bytes memory sig = _signCreate(owner, operator, address(exchange), deadline, ownerKey);
        factory.createWithSignature(owner, operator, address(exchange), deadline, sig);

        assertEq(factory.nonces(owner), 1);
    }

    function test_CreateWithSignature_RevertsOnReplay() external {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _signCreate(owner, operator, address(exchange), deadline, ownerKey);

        factory.createWithSignature(owner, operator, address(exchange), deadline, sig);

        vm.expectRevert(DelegatedAccountFactory.InvalidSignature.selector);
        factory.createWithSignature(owner, operator, address(exchange), deadline, sig);
    }

    function test_CreateWithSignature_RevertsIfExpired() external {
        uint256 deadline = block.timestamp - 1;
        bytes memory sig = _signCreate(owner, operator, address(exchange), deadline, ownerKey);

        vm.expectRevert(DelegatedAccountFactory.SignatureExpired.selector);
        factory.createWithSignature(owner, operator, address(exchange), deadline, sig);
    }

    function test_CreateWithSignature_RevertsIfInvalidSig() external {
        uint256 deadline = block.timestamp + 1 hours;
        (, uint256 wrongKey) = makeAddrAndKey("wrong");
        bytes memory sig = _signCreate(owner, operator, address(exchange), deadline, wrongKey);

        vm.expectRevert(DelegatedAccountFactory.InvalidSignature.selector);
        factory.createWithSignature(owner, operator, address(exchange), deadline, sig);
    }

    function test_BeaconUpgrade_AppliesToAllFactoryInstances() external {
        // Create two instances
        vm.prank(owner);
        address proxy1 = factory.create(owner, operator, address(exchange));
        vm.prank(owner);
        address proxy2 = factory.create(owner, operator, address(exchange));

        // Upgrade beacon
        DelegatedAccountV2 newImpl = new DelegatedAccountV2();
        UpgradeableBeacon b = factory.beacon();
        vm.prank(beaconOwner);
        b.upgradeTo(address(newImpl));

        // Both should be upgraded
        assertEq(DelegatedAccountV2(payable(proxy1)).version(), 2);
        assertEq(DelegatedAccountV2(payable(proxy2)).version(), 2);
    }

    function test_BeaconOwnership() external view {
        assertEq(factory.beacon().owner(), beaconOwner);
    }
}
