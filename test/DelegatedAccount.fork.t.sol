// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {DelegatedAccount} from "../src/DelegatedAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IExchange} from "../interfaces/IExchange.sol";
import {IExchangeErrors} from "../interfaces/IExchangeErrors.sol";
import {DelegatedAccountFactory} from "../src/DelegatedAccountFactory.sol";
import {
    SignOperatorScript,
    SetupDelegatedAccountScript,
    SyncOperatorAllowlistScript
} from "../script/DelegatedAccount.s.sol";

/// @notice Fork tests against Monad testnet
/// @dev Run with: forge test --match-contract Fork
abstract contract Base_Fork_Test is Test {
    // ============ Monad Testnet Constants ============
    string constant MONAD_RPC_URL = "https://testnet-rpc.monad.xyz";
    uint256 constant FORK_BLOCK_NUMBER = 47_660_000; // Pinned block for deterministic tests
    address constant MONAD_EXCHANGE = 0x1964C32f0bE608E7D29302AFF5E61268E72080cc;
    address constant MONAD_EXCHANGE_OWNER = 0x9BE11AD8116d636f03aD7ab213ff6827B7Cc56EF;
    address constant MONAD_COLLATERAL_TOKEN = 0xa9012a055bd4e0eDfF8Ce09f960291C09D5322dC; // AUSD, 6 decimals

    // ============ Contracts ============
    DelegatedAccount public delegatedAccount;
    DelegatedAccount public implementation;
    UpgradeableBeacon public beacon;
    IERC20 public token;
    SignOperatorScript public signOperatorScript;

    // ============ Addresses ============
    address public owner;
    address public operator;
    uint256 public operatorKey;
    address public user;

    // ============ Constants ============
    uint256 public constant INITIAL_BALANCE = 1_000_000e6;
    uint256 public constant DEPOSIT_AMOUNT = 100_000e6;

    // ============ Selectors (for error checking) ============
    bytes4 constant WITHDRAW_COLLATERAL = 0x6112fe2e;
    bytes4 constant XFER_ACCT_TO_PROTOCOL = 0x61bd6f44;

    /// @notice BTC-PERP, priceDecimals = 1, lotDecimals = 5
    uint256 constant BTC_PERP_ID = 0x10;

    // ============ Setup ============
    function setUp() public virtual {
        // Create fork at pinned block number for deterministic tests
        vm.createSelectFork(MONAD_RPC_URL, FORK_BLOCK_NUMBER);

        signOperatorScript = new SignOperatorScript();

        // Create addresses
        owner = makeAddr("owner");
        (operator, operatorKey) = makeAddrAndKey("operator");
        user = makeAddr("user");

        // Use real contracts on Monad testnet
        token = IERC20(MONAD_COLLATERAL_TOKEN);

        // Deploy implementation and beacon
        implementation = new DelegatedAccount();
        beacon = new UpgradeableBeacon(address(implementation), address(this));

        // Deploy proxy with initialization (collateral token is fetched from exchange)
        bytes memory initData =
            abi.encodeWithSelector(DelegatedAccount.initialize.selector, owner, operator, MONAD_EXCHANGE);
        BeaconProxy proxy = new BeaconProxy(address(beacon), initData);
        delegatedAccount = DelegatedAccount(payable(address(proxy)));

        // Deal tokens for testing
        _dealCollateral(owner, INITIAL_BALANCE);
        _dealCollateral(operator, INITIAL_BALANCE);
        _dealCollateral(address(delegatedAccount), INITIAL_BALANCE);
    }

    // ============ Helpers ============

    /// @notice Set a collateral token balance directly in storage
    /// @dev `deal()` cannot be used: AUSD packs its account data into a single slot as
    ///      `{uint8 flags; uint248 balance}`, so a raw slot write of `amount` (what StdStorage
    ///      probes with) does not round-trip through `balanceOf`. The balance slot is located by
    ///      recording the SLOADs of a `balanceOf` call, then rewritten with the flags byte preserved.
    function _dealCollateral(address to, uint256 amount) internal {
        vm.record();
        token.balanceOf(to);
        (bytes32[] memory reads,) = vm.accesses(address(token));
        bytes32 slot = reads[reads.length - 1];

        uint256 current = uint256(vm.load(address(token), slot));
        vm.store(address(token), slot, bytes32((amount << 8) | (current & 0xff)));

        assertEq(token.balanceOf(to), amount, "_dealCollateral: unexpected token storage layout");
    }

    /// @notice Build a post-only long on BTC-PERP that rests on the book instead of matching
    /// @dev Prices are absolute PNS; the book exposes them as ONS (offsets from `basePricePNS`).
    ///      The bid is placed one dollar under the current best bid so it can never cross the
    ///      spread — a post-only order that would match is rejected by the exchange.
    function _btcPostOnlyBid() internal view returns (IExchange.OrderDesc memory) {
        IExchange.PerpetualInfo memory perp = IExchange(MONAD_EXCHANGE).getPerpetualInfo(BTC_PERP_ID);
        uint256 bestBidPNS = perp.basePricePNS + perp.maxBidPriceONS;

        return IExchange.OrderDesc({
            orderDescId: 0,
            perpId: BTC_PERP_ID,
            orderType: IExchange.OrderDescEnum.wrap(uint8(OrderDescEnum.OpenLong)),
            orderId: 0,
            pricePNS: bestBidPNS - 10, // $1 below best bid (priceDecimals = 1)
            lotLNS: 10, // 0.0001 BTC (lotDecimals = 5)
            expiryBlock: block.number + 1000,
            postOnly: true,
            fillOrKill: false,
            immediateOrCancel: false,
            maxMatches: 0,
            leverageHdths: 100, // 1x leverage
            lastExecutionBlock: 0,
            amountCNS: 0,
            maxNegPnlCollatBPS: 0
        });
    }

    /// @notice Sign an operator consent for DelegatedAccount.addOperator()
    function _signAddOperator(address _delegatedAccount, address _owner, uint256 _deadline, uint256 _operatorPrivKey)
        internal
        view
        returns (bytes memory sig)
    {
        (sig,) =
            signOperatorScript.sign(_delegatedAccount, _owner, vm.addr(_operatorPrivKey), _deadline, _operatorPrivKey);
    }

    /// @notice Create an account on the exchange via the DelegatedAccount
    function _createAccount(uint256 amount) internal {
        vm.prank(owner);
        delegatedAccount.createAccount(amount);
    }

    /// @notice Deploy a new DelegatedAccount proxy with given parameters
    function _deployProxy(address _owner, address _operator, address _exchange) internal returns (DelegatedAccount) {
        bytes memory initData =
            abi.encodeWithSelector(DelegatedAccount.initialize.selector, _owner, _operator, _exchange);
        BeaconProxy proxy = new BeaconProxy(address(beacon), initData);
        return DelegatedAccount(payable(address(proxy)));
    }
}

// ============================================================================
// Fork: Constructor Tests
// ============================================================================

contract Fork_Initialize_Test is Base_Fork_Test {
    function test_WhenAllParametersAreValid() external view {
        // it should set the owner.
        assertEq(delegatedAccount.owner(), owner);

        // it should set the operator.
        assertTrue(delegatedAccount.isOperator(operator));

        // it should set the exchange.
        assertEq(delegatedAccount.exchange(), MONAD_EXCHANGE);

        // it should set the collateralToken.
        assertEq(address(delegatedAccount.collateralToken()), MONAD_COLLATERAL_TOKEN);

        // it should initialize operator allowlist with default selectors.
        assertTrue(delegatedAccount.operatorAllowlist(0x4d8dc985)); // execOrder
        assertTrue(delegatedAccount.operatorAllowlist(0x39435dac)); // execOrders
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
        DelegatedAccount newDelegatedAccount = _deployProxy(newOwner, operator, MONAD_EXCHANGE);

        // Give it just 1 wei - not enough for Exchange minimum
        _dealCollateral(address(newDelegatedAccount), 1);

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
// Fork: Operator Management Tests
// ============================================================================

contract Fork_OperatorManagement_Test is Base_Fork_Test {
    function test_AddOperator_WhenCallerIsOwner() external {
        (address newOperator, uint256 newOperatorKey) = makeAddrAndKey("newOperator");
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _signAddOperator(address(delegatedAccount), owner, deadline, newOperatorKey);

        // it should emit OperatorAdded event.
        vm.expectEmit(true, false, false, false);
        emit DelegatedAccount.OperatorAdded(newOperator);

        vm.prank(owner);
        delegatedAccount.addOperator(newOperator, deadline, sig);

        // it should add operator.
        assertTrue(delegatedAccount.isOperator(newOperator));
    }

    function test_AddOperator_RevertWhen_CallerIsNotOwner() external {
        uint256 deadline = block.timestamp + 1 hours;
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        delegatedAccount.addOperator(user, deadline, "");
    }

    function test_AddOperator_RevertWhen_ZeroAddress() external {
        vm.prank(owner);
        vm.expectRevert(DelegatedAccount.ZeroAddress.selector);
        delegatedAccount.addOperator(address(0), 0, "");
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

    function test_RemoveOperator_RevertWhen_CallerIsNotOwner() external {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        delegatedAccount.removeOperator(operator);
    }

    function test_MultipleOperators() external {
        (address operator2, uint256 operator2Key) = makeAddrAndKey("operator2");
        (address operator3, uint256 operator3Key) = makeAddrAndKey("operator3");
        uint256 deadline = block.timestamp + 1 hours;

        vm.startPrank(owner);
        bytes memory sig2 = _signAddOperator(address(delegatedAccount), owner, deadline, operator2Key);
        delegatedAccount.addOperator(operator2, deadline, sig2);
        bytes memory sig3 = _signAddOperator(address(delegatedAccount), owner, deadline, operator3Key);
        delegatedAccount.addOperator(operator3, deadline, sig3);
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
        uint256 rescueAmount = 50_000e6;
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
        assertTrue(delegatedAccount.operatorAllowlist(0x4d8dc985)); // execOrder
        assertTrue(delegatedAccount.operatorAllowlist(0x39435dac)); // execOrders
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

        uint256 additionalDeposit = 50_000e6;

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

        uint256 additionalDeposit = 50_000e6;

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

    function test_ExecOrder_Owner() external {
        _createAccount(DEPOSIT_AMOUNT);

        vm.prank(MONAD_EXCHANGE_OWNER);
        exchange.setIgnOracle(BTC_PERP_ID, true);

        // Built before the prank: reading the book would otherwise consume it
        IExchange.OrderDesc memory orderDesc = _btcPostOnlyBid();

        // Owner executes order via fallback - should succeed
        vm.prank(owner);
        IExchange.OrderSignature memory sig = delegatedAccountAsExchange.execOrder(orderDesc);

        // Verify order was created
        assertGt(sig.orderId, 0);
        assertEq(sig.perpId, BTC_PERP_ID);
    }

    function test_ExecOrder_Operator() external {
        _createAccount(DEPOSIT_AMOUNT);

        vm.prank(MONAD_EXCHANGE_OWNER);
        exchange.setIgnOracle(BTC_PERP_ID, true);

        // Built before the prank: reading the book would otherwise consume it
        IExchange.OrderDesc memory orderDesc = _btcPostOnlyBid();

        // Operator executes order via fallback (allowlisted) - should succeed
        vm.prank(operator);
        IExchange.OrderSignature memory sig = delegatedAccountAsExchange.execOrder(orderDesc);

        // Verify order was created
        assertGt(sig.orderId, 0);
        assertEq(sig.perpId, BTC_PERP_ID);
    }
}

// ============================================================================
// Fork: Allowlist Repair on Accounts Minted by the Deployed Factory
// ============================================================================

/// @notice The DelegatedAccountFactory already live on Monad testnet points at a beacon whose
///         implementation was compiled against the previous Exchange ABI. Accounts it mints are
///         therefore born with a stale operator allowlist. These tests pin that down and prove
///         SetupDelegatedAccountScript repairs it in place, so the factory stays usable without a
///         redeployment.
/// @dev The script contract is made the account owner because `syncOperatorAllowlist` issues
///      several owner-only calls; under a real run `vm.startBroadcast()` puts the EOA in that seat.
contract Fork_DeployedFactoryAllowlist_Test is Base_Fork_Test {
    address constant MONAD_FACTORY = 0xf42548Ccb3300Bc76c35dc2D347416db2E8d7209;

    SetupDelegatedAccountScript public setupScript;
    DelegatedAccount public factoryAccount;
    address public accountOwner;

    function setUp() public override {
        super.setUp();

        setupScript = new SetupDelegatedAccountScript();
        accountOwner = address(setupScript);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory opSig = _signAddOperator(MONAD_FACTORY, accountOwner, deadline, operatorKey);

        vm.prank(accountOwner);
        factoryAccount =
            DelegatedAccount(payable(DelegatedAccountFactory(MONAD_FACTORY).create(operator, deadline, opSig)));

        _dealCollateral(address(factoryAccount), INITIAL_BALANCE);
    }

    function test_DeployedFactory_MintsStaleAllowlist() external view {
        // Sanity: the account really came from the deployed factory and knows this exchange
        assertEq(factoryAccount.exchange(), MONAD_EXCHANGE);
        assertTrue(factoryAccount.isOperator(operator));

        // Every selector the script would revoke is present...
        bytes4[] memory stale = setupScript.staleAllowlist();
        for (uint256 i = 0; i < stale.length; i++) {
            assertTrue(factoryAccount.operatorAllowlist(stale[i]), "expected stale selector to be set");
        }

        // ...and the selectors that replaced them are not
        assertFalse(factoryAccount.operatorAllowlist(IExchange.execOrder.selector));
        assertFalse(factoryAccount.operatorAllowlist(IExchange.execOrders.selector));
    }

    function test_SyncOperatorAllowlist_GrantsCurrentAndRevokesStale() external {
        setupScript.syncOperatorAllowlist(factoryAccount);

        bytes4[] memory current = setupScript.currentAllowlist();
        for (uint256 i = 0; i < current.length; i++) {
            assertTrue(factoryAccount.operatorAllowlist(current[i]), "current selector not granted");
        }

        bytes4[] memory stale = setupScript.staleAllowlist();
        for (uint256 i = 0; i < stale.length; i++) {
            assertFalse(factoryAccount.operatorAllowlist(stale[i]), "stale selector not revoked");
        }
    }

    function test_SyncOperatorAllowlist_IsIdempotent() external {
        setupScript.syncOperatorAllowlist(factoryAccount);
        setupScript.syncOperatorAllowlist(factoryAccount);

        bytes4[] memory current = setupScript.currentAllowlist();
        for (uint256 i = 0; i < current.length; i++) {
            assertTrue(factoryAccount.operatorAllowlist(current[i]));
        }
    }

    /// @dev The broadcaster must own the account being repaired. Pranking a different caller proves
    ///      nothing here — `syncOperatorAllowlist` always reaches the account as the script itself —
    ///      so the case that matters is an account owned by somebody else.
    function test_SyncOperatorAllowlist_RevertWhen_ScriptIsNotOwner() external {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory opSig = _signAddOperator(MONAD_FACTORY, owner, deadline, operatorKey);

        vm.prank(owner);
        DelegatedAccount otherAccount =
            DelegatedAccount(payable(DelegatedAccountFactory(MONAD_FACTORY).create(operator, deadline, opSig)));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(setupScript)));
        setupScript.syncOperatorAllowlist(otherAccount);
    }

    /// @dev SetupDelegatedAccountScript cannot repair an account whose exchange account already
    ///      exists — its `createAccount` call would revert with AccountAlreadyCreated. The
    ///      standalone script is the path for those, so it has to work after setup has run.
    function test_SyncScript_RepairsAlreadySetUpAccount() external {
        SyncOperatorAllowlistScript syncScript = new SyncOperatorAllowlistScript();

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory opSig = _signAddOperator(MONAD_FACTORY, address(syncScript), deadline, operatorKey);

        vm.prank(address(syncScript));
        DelegatedAccount liveAccount =
            DelegatedAccount(payable(DelegatedAccountFactory(MONAD_FACTORY).create(operator, deadline, opSig)));

        _dealCollateral(address(liveAccount), INITIAL_BALANCE);
        vm.prank(address(syncScript));
        liveAccount.createAccount(DEPOSIT_AMOUNT);
        assertGt(liveAccount.accountId(), 0);

        syncScript.syncOperatorAllowlist(liveAccount);

        bytes4[] memory current = syncScript.currentAllowlist();
        for (uint256 i = 0; i < current.length; i++) {
            assertTrue(liveAccount.operatorAllowlist(current[i]), "current selector not granted");
        }

        bytes4[] memory stale = syncScript.staleAllowlist();
        for (uint256 i = 0; i < stale.length; i++) {
            assertFalse(liveAccount.operatorAllowlist(stale[i]), "stale selector not revoked");
        }
    }

    /// @dev The keeper-side settlement call stays off the allowlist in both directions: the old
    ///      signature is revoked and the current one is never granted.
    function test_SyncOperatorAllowlist_DoesNotGrantDecreasePositionCollateral() external {
        assertTrue(factoryAccount.operatorAllowlist(0x4a1feb12), "expected legacy selector to be set");

        setupScript.syncOperatorAllowlist(factoryAccount);

        assertFalse(factoryAccount.operatorAllowlist(0x4a1feb12));
        assertFalse(factoryAccount.operatorAllowlist(IExchange.decreasePositionCollateral.selector));
    }

    /// @dev The end-to-end point of the repair: an operator on a factory-minted account can trade.
    function test_SyncOperatorAllowlist_UnblocksOperatorExecOrder() external {
        vm.prank(accountOwner);
        factoryAccount.createAccount(DEPOSIT_AMOUNT);

        vm.prank(MONAD_EXCHANGE_OWNER);
        IExchange(MONAD_EXCHANGE).setIgnOracle(BTC_PERP_ID, true);

        IExchange.OrderDesc memory orderDesc = _btcPostOnlyBid();

        // Before the repair the operator is turned away by the stale allowlist
        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(DelegatedAccount.SelectorNotAllowed.selector, IExchange.execOrder.selector)
        );
        IExchange(address(factoryAccount)).execOrder(orderDesc);

        setupScript.syncOperatorAllowlist(factoryAccount);

        vm.prank(operator);
        IExchange.OrderSignature memory sig = IExchange(address(factoryAccount)).execOrder(orderDesc);

        assertGt(sig.orderId, 0);
        assertEq(sig.perpId, BTC_PERP_ID);
    }
}

/// @notice Mirrors `OrderDescEnum` from the exchange sources; the generated interface flattens it
///         to a `uint8` user-defined value type, which loses the variant names.
enum OrderDescEnum {
    OpenLong,
    OpenShort,
    CloseLong,
    CloseShort,
    Cancel,
    IncreasePositionCollateral,
    Change
}
