// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {DelegatedAccount} from "../src/DelegatedAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IExchangeErrors} from "../interfaces/IExchangeErrors.sol";

/// @notice Fork tests against Monad testnet
/// @dev Run with: forge test --match-contract Fork
abstract contract Base_Fork_Test is Test {
    // ============ Monad Testnet Constants ============
    string constant MONAD_RPC_URL = "https://monad-testnet.drpc.org";
    uint256 constant FORK_BLOCK_NUMBER = 7_660_000; // Pinned block for deterministic tests
    address constant MONAD_EXCHANGE = 0x9C216D1Ab3e0407b3d6F1d5e9EfFe6d01C326ab7;
    address constant MONAD_COLLATERAL_TOKEN = 0xdF5B718d8FcC173335185a2a1513eE8151e3c027;

    // ============ Contracts ============
    DelegatedAccount public delegatedAccount;
    IERC20 public token;

    // ============ Addresses ============
    address public owner;
    address public operator;
    address public user;

    // ============ Constants ============
    uint256 public constant INITIAL_BALANCE = 1_000_000e18;
    uint256 public constant DEPOSIT_AMOUNT = 100_000e18;

    // ============ Selectors (for error checking) ============
    bytes4 constant WITHDRAW_COLLATERAL = 0x6112fe2e;
    bytes4 constant XFER_ACCT_TO_PROTOCOL = 0x61bd6f44;

    // ============ Setup ============
    function setUp() public virtual {
        // Create fork at pinned block number for deterministic tests
        vm.createSelectFork(MONAD_RPC_URL, FORK_BLOCK_NUMBER);

        // Create addresses
        owner = makeAddr("owner");
        operator = makeAddr("operator");
        user = makeAddr("user");

        // Use real contracts on Monad testnet
        token = IERC20(MONAD_COLLATERAL_TOKEN);

        // Deploy DelegatedAccount pointing to real exchange
        delegatedAccount = new DelegatedAccount(owner, operator, MONAD_EXCHANGE, address(token));

        // Deal tokens for testing
        deal(address(token), owner, INITIAL_BALANCE);
        deal(address(token), operator, INITIAL_BALANCE);
        deal(address(token), address(delegatedAccount), INITIAL_BALANCE);
    }

    // ============ Helpers ============

    /// @notice Create an account on the exchange via the DelegatedAccount
    function _createAccount(uint256 amount) internal {
        vm.prank(owner);
        delegatedAccount.createAccount(amount);
    }
}

// ============================================================================
// Fork: Constructor Tests
// ============================================================================

contract Fork_Constructor_Test is Base_Fork_Test {
    function test_WhenAllParametersAreValid() external view {
        // it should set the owner.
        assertEq(delegatedAccount.owner(), owner);

        // it should set the operator.
        assertEq(delegatedAccount.operator(), operator);

        // it should set the exchange.
        assertEq(delegatedAccount.EXCHANGE(), MONAD_EXCHANGE);

        // it should set the collateralToken.
        assertEq(address(delegatedAccount.COLLATERAL_TOKEN()), MONAD_COLLATERAL_TOKEN);

        // it should initialize operator allowlist with default selectors.
        assertTrue(delegatedAccount.operatorAllowlist(0x6b69ebbe)); // execOrder
        assertTrue(delegatedAccount.operatorAllowlist(0xaf3176da)); // execOrders
        assertTrue(delegatedAccount.operatorAllowlist(0xbad4a01f)); // depositCollateral
    }
}

// ============================================================================
// Fork: CreateAccount Tests
// ============================================================================

contract Fork_CreateAccount_Test is Base_Fork_Test {
    function test_WhenAccountDoesNotExist() external {
        vm.prank(owner);
        delegatedAccount.createAccount(DEPOSIT_AMOUNT);

        // it should store the accountId (any non-zero value on fork)
        assertGt(delegatedAccount.accountId(), 0);
    }

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

    function test_RevertWhen_ExchangeCallFails_BubblesUpExchangeError() external {
        // Deploy a new DelegatedAccount with minimal tokens (less than required)
        address newOwner = makeAddr("newOwner");
        DelegatedAccount newDelegatedAccount = new DelegatedAccount(newOwner, operator, MONAD_EXCHANGE, address(token));

        // Give it just 1 wei - not enough for Exchange minimum
        deal(address(token), address(newDelegatedAccount), 1);

        // Exchange should revert with InsufficentAmountToOpenAccount and error should bubble up
        vm.prank(newOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IExchangeErrors.InsufficentAmountToOpenAccount.selector, address(newDelegatedAccount), 1
            )
        );
        newDelegatedAccount.createAccount(1);
    }
}

// ============================================================================
// Fork: TransferOwnership Tests
// ============================================================================

contract Fork_TransferOwnership_Test is Base_Fork_Test {
    function test_WhenNewOwnerIsValid_TwoStepTransfer() external {
        address newOwner = makeAddr("newOwner");

        // Step 1: Transfer ownership (sets pending owner)
        vm.prank(owner);
        delegatedAccount.transferOwnership(newOwner);

        // Owner should still be the original owner
        assertEq(delegatedAccount.owner(), owner);
        assertEq(delegatedAccount.pendingOwner(), newOwner);

        // Step 2: New owner accepts ownership
        vm.prank(newOwner);
        delegatedAccount.acceptOwnership();

        // Now ownership is transferred
        assertEq(delegatedAccount.owner(), newOwner);
        assertEq(delegatedAccount.pendingOwner(), address(0));
    }

    function test_RevertWhen_CallerIsNotOwner() external {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        delegatedAccount.transferOwnership(user);
    }
}

// ============================================================================
// Fork: SetOperator Tests
// ============================================================================

contract Fork_SetOperator_Test is Base_Fork_Test {
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

    function test_RevertWhen_CallerIsNotOwner() external {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        delegatedAccount.setOperator(user);
    }
}

// ============================================================================
// Fork: SetOperatorAllowlist Tests
// ============================================================================

contract Fork_SetOperatorAllowlist_Test is Base_Fork_Test {
    function test_WhenAddingSelector() external {
        bytes4 selector = 0x12345678;
        assertFalse(delegatedAccount.operatorAllowlist(selector));

        // it should emit OperatorAllowlistUpdated event.
        vm.expectEmit(true, false, false, true);
        emit DelegatedAccount.OperatorAllowlistUpdated(selector, true);

        vm.prank(owner);
        delegatedAccount.setOperatorAllowlist(selector, true);

        // it should update allowlist.
        assertTrue(delegatedAccount.operatorAllowlist(selector));
    }

    function test_RevertWhen_CallerIsNotOwner() external {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        delegatedAccount.setOperatorAllowlist(0x12345678, true);
    }
}

// ============================================================================
// Fork: Fallback Tests
// ============================================================================

contract Fork_Fallback_Test is Base_Fork_Test {
    IExchange delegatedAccountAsExchange;

    function setUp() public override {
        super.setUp();
        delegatedAccountAsExchange = IExchange(address(delegatedAccount));
    }

    function test_RevertWhen_CallerIsNotOwnerOrOperator() external {
        vm.prank(user);
        vm.expectRevert(DelegatedAccount.OnlyOwnerOrOperator.selector);
        delegatedAccountAsExchange.depositCollateral(DEPOSIT_AMOUNT);
    }

    function test_RevertWhen_CallerIsOperator_AccountDoesNotExist() external {
        // Use allowOrderForwarding which goes through fallback (depositCollateral is now a direct function)
        vm.prank(operator);
        vm.expectRevert(DelegatedAccount.AccountNotCreated.selector);
        delegatedAccountAsExchange.allowOrderForwarding(true);
    }

    function test_RevertWhen_CallerIsOperator_SelectorNotAllowlisted() external {
        _createAccount(DEPOSIT_AMOUNT);

        // Use xferAcctToProtocol which goes through fallback
        // (withdrawCollateral is a direct function on DelegatedAccount with onlyOwner)
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(DelegatedAccount.SelectorNotAllowed.selector, XFER_ACCT_TO_PROTOCOL));
        delegatedAccountAsExchange.xferAcctToProtocol(DEPOSIT_AMOUNT);
    }

    function test_WhenCallerIsOwner_CanCallAnySelector() external {
        _createAccount(DEPOSIT_AMOUNT);

        // Owner can call depositCollateral via fallback (infinite approval in constructor)
        vm.prank(owner);
        delegatedAccountAsExchange.depositCollateral(DEPOSIT_AMOUNT);
    }

    function test_WhenCallerIsOperator_AllowlistedSelector() external {
        _createAccount(DEPOSIT_AMOUNT);

        // Operator can call depositCollateral via fallback (allowlisted, infinite approval in constructor)
        vm.prank(operator);
        delegatedAccountAsExchange.depositCollateral(DEPOSIT_AMOUNT);
    }
}

// ============================================================================
// Fork: WithdrawCollateral Tests
// ============================================================================

contract Fork_WithdrawCollateral_Test is Base_Fork_Test {
    function test_RevertWhen_CallerIsNotOwner() external {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        delegatedAccount.withdrawCollateral(DEPOSIT_AMOUNT);
    }
}

// ============================================================================
// Fork: RescueTokens Tests
// ============================================================================

contract Fork_RescueTokens_Test is Base_Fork_Test {
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
// Fork: IsOperatorAllowed Tests
// ============================================================================

contract Fork_IsOperatorAllowed_Test is Base_Fork_Test {
    function test_WhenSelectorIsAllowlisted() external view {
        assertTrue(delegatedAccount.operatorAllowlist(0x6b69ebbe)); // execOrder
        assertTrue(delegatedAccount.operatorAllowlist(0xaf3176da)); // execOrders
        assertTrue(delegatedAccount.operatorAllowlist(0xbad4a01f)); // depositCollateral
    }

    function test_WhenSelectorIsNotAllowlisted() external view {
        assertFalse(delegatedAccount.operatorAllowlist(WITHDRAW_COLLATERAL));
        assertFalse(delegatedAccount.operatorAllowlist(XFER_ACCT_TO_PROTOCOL));
        assertFalse(delegatedAccount.operatorAllowlist(0x12345678));
    }
}

// ============================================================================
// Fork: Exchange Operations Tests (via fallback)
// ============================================================================

contract Fork_ExchangeOperations_Test is Base_Fork_Test {
    /// @notice Exchange interface for querying account info
    IExchange public exchange;

    /// @notice DelegatedAccount cast to IExchange for calling exchange functions via fallback
    IExchange public delegatedAccountAsExchange;

    function setUp() public override {
        super.setUp();
        exchange = IExchange(MONAD_EXCHANGE);
        delegatedAccountAsExchange = IExchange(address(delegatedAccount));
    }

    // ============ depositCollateral ============

    function test_DepositCollateral_Owner() external {
        _createAccount(DEPOSIT_AMOUNT);

        uint256 additionalDeposit = 50_000e18;

        // Get account balance before
        IExchange.AccountInfo memory infoBefore = exchange.getAccountById(delegatedAccount.accountId());
        uint256 balanceBefore = infoBefore.balanceCNS;

        // Owner deposits additional collateral via fallback (infinite approval in constructor)
        vm.prank(owner);
        delegatedAccountAsExchange.depositCollateral(additionalDeposit);

        // Verify balance increased
        IExchange.AccountInfo memory infoAfter = exchange.getAccountById(delegatedAccount.accountId());
        assertEq(infoAfter.balanceCNS, balanceBefore + additionalDeposit);
    }

    function test_DepositCollateral_Operator() external {
        _createAccount(DEPOSIT_AMOUNT);

        uint256 additionalDeposit = 50_000e18;

        // Get account balance before
        IExchange.AccountInfo memory infoBefore = exchange.getAccountById(delegatedAccount.accountId());
        uint256 balanceBefore = infoBefore.balanceCNS;

        // Operator deposits additional collateral via fallback (infinite approval in constructor)
        vm.prank(operator);
        delegatedAccountAsExchange.depositCollateral(additionalDeposit);

        // Verify balance increased
        IExchange.AccountInfo memory infoAfter = exchange.getAccountById(delegatedAccount.accountId());
        assertEq(infoAfter.balanceCNS, balanceBefore + additionalDeposit);
    }

    // ============ allowOrderForwarding ============

    function test_AllowOrderForwarding_Owner_Enable() external {
        _createAccount(DEPOSIT_AMOUNT);

        // Owner enables order forwarding
        vm.prank(owner);
        delegatedAccountAsExchange.allowOrderForwarding(true);
    }

    function test_AllowOrderForwarding_Owner_Disable() external {
        _createAccount(DEPOSIT_AMOUNT);

        // Owner disables order forwarding
        vm.prank(owner);
        delegatedAccountAsExchange.allowOrderForwarding(false);
    }

    function test_AllowOrderForwarding_Operator() external {
        _createAccount(DEPOSIT_AMOUNT);

        // Operator enables order forwarding (allowlisted)
        vm.prank(operator);
        delegatedAccountAsExchange.allowOrderForwarding(true);
    }

    // ============ execOrder ============
    // BTC-PERP config: base_price_pns=50000, price_decimals=1, lot_decimals=5

    function test_ExecOrder_Owner() external {
        _createAccount(DEPOSIT_AMOUNT);

        // Create a limit bid order on BTC-PERP (perpId 0x10)
        // Price ~$50,000 (within allowed range), small lot size
        IExchange.OrderDesc memory orderDesc = IExchange.OrderDesc({
            orderDescId: 0,
            perpId: 0x10, // BTC-PERP
            orderType: IExchange.OrderDescEnum.BID,
            orderId: 0,
            pricePNS: 100_000, // Price in PNS format (no e18 decimals)
            lotLNS: 100, // Small lot in LNS format
            expiryBlock: block.number + 1000,
            postOnly: true,
            fillOrKill: false,
            immediateOrCancel: false,
            maxMatches: 0,
            leverageHdths: 100, // 1x leverage
            lastExecutionBlock: 0,
            amountCNS: 0
        });

        // Owner executes order via fallback - should succeed
        vm.prank(owner);
        IExchange.OrderSignature memory sig = delegatedAccountAsExchange.execOrder(orderDesc);

        // Verify order was created
        assertGt(sig.orderId, 0);
        assertEq(sig.perpId, 0x10);
    }

    function test_ExecOrder_Operator() external {
        _createAccount(DEPOSIT_AMOUNT);

        // Create a limit bid order on BTC-PERP (perpId 0x10)
        IExchange.OrderDesc memory orderDesc = IExchange.OrderDesc({
            orderDescId: 0,
            perpId: 0x10, // BTC-PERP
            orderType: IExchange.OrderDescEnum.BID,
            orderId: 0,
            pricePNS: 100_000, // Price in PNS format (no e18 decimals)
            lotLNS: 100, // Small lot in LNS format
            expiryBlock: block.number + 1000,
            postOnly: true,
            fillOrKill: false,
            immediateOrCancel: false,
            maxMatches: 0,
            leverageHdths: 100, // 1x leverage
            lastExecutionBlock: 0,
            amountCNS: 0
        });

        // Operator executes order via fallback (allowlisted) - should succeed
        vm.prank(operator);
        IExchange.OrderSignature memory sig = delegatedAccountAsExchange.execOrder(orderDesc);

        // Verify order was created
        assertGt(sig.orderId, 0);
        assertEq(sig.perpId, 0x10);
    }
}

/// @notice Minimal interface for Exchange calls in tests
interface IExchange {
    enum OrderDescEnum {
        BID,
        ASK
    }

    struct OrderDesc {
        uint256 orderDescId;
        uint256 perpId;
        OrderDescEnum orderType;
        uint256 orderId;
        uint256 pricePNS;
        uint256 lotLNS;
        uint256 expiryBlock;
        bool postOnly;
        bool fillOrKill;
        bool immediateOrCancel;
        uint256 maxMatches;
        uint256 leverageHdths;
        uint256 lastExecutionBlock;
        uint256 amountCNS;
    }

    struct OrderSignature {
        uint256 perpId;
        uint256 orderId;
    }

    struct AccountInfo {
        uint256 accountId;
        uint256 balanceCNS;
        uint256 lockedBalanceCNS;
        uint8 frozen;
        address accountAddr;
        PositionBitMap positions;
    }

    struct PositionBitMap {
        uint256 bank1;
        uint256 bank2;
        uint256 bank3;
        uint256 bank4;
    }

    function getAccountById(uint256 accountId) external view returns (AccountInfo memory);
    function depositCollateral(uint256 amountCNS) external;
    function allowOrderForwarding(bool allow) external;
    function execOrder(OrderDesc memory orderDesc) external returns (OrderSignature memory);
    function xferAcctToProtocol(uint256 amountCNS) external;
}
