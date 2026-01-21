// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IExchangeEvents {
    type FreezeStatusEnum is uint8;
    type OrderDescEnum is uint8;
    type OrderEnum is uint8;
    type PositionEnum is uint8;

    event AccountCreated(address account, uint256 id);
    event AccountFreeze(uint256 accountId, FreezeStatusEnum status);
    event AccountFrozen(FreezeStatusEnum status);
    event AccountLiquidationCredit(uint256 perpId, uint256 accountId, uint256 startBalanceCNS, uint256 endBalanceCNS);
    event AdminChanged(address previousAdmin, address newAdmin);
    event AdministratorUpdated(address administrator, bool added);
    event AmountExceedsAvailableBalance(uint256 amountCNS, uint256 availableBalanceCNS, uint256 balanceCNS);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event BankruptcyPricePreventsDeleverage(
        uint256 perpId, uint256 accountId, PositionEnum positionType, uint256 bankruptcyPricePNS, uint256 markPricePNS
    );
    event BeaconUpgraded(address indexed beacon);
    event BlockStatusChanged(address indexed addr, bool blocked);
    event BorrowMarginNotMetAfterDecCollateral(uint256 perpId, uint256 accountId, int256 bmrCNS, int256 fmvAfterCNS);
    event BuyToLiquidateBuyerRestricted(uint256 perpId, address buyer);
    event BuyToLiquidateParamsUpdated(
        uint256 perpId, uint256 insAmtPer100K, uint256 userAmtPer100K, uint256 buyerAmtPer100K, uint256 protAmtPer100K
    );
    event BuyToLiquidateRestrictionUpdated(uint256 perpId, bool restrictBuyers);
    event BuyToLiquidateSlippageExceeded(
        uint256 perpId, uint256 posAccountId, PositionEnum positionType, uint256 markPricePNS, uint256 limitPricePNS
    );
    event BuyToLiquidateThresholdUpdated(uint256 perpId, uint256 thresholdPer100K);
    event CancelExistingInvalidCloseOrders(
        uint256 lockedLotLNS, PositionEnum lockedPositionType, PositionEnum newPositionType
    );
    event CannotAdjustEntryPriceToDecCollateral(
        uint256 perpId,
        uint256 accountId,
        uint256 amountCNS,
        uint256 adjustmentAmountCNS,
        uint256 entryPricePNS,
        int256 adjustedEntryPricePNS,
        PositionEnum positionType
    );
    event CantBuyToLiquidate(
        uint256 perpId,
        uint256 posAccountId,
        PositionEnum positionType,
        uint256 markPricePNS,
        uint256 bsLiqPricePNS,
        uint256 liqPricePNS,
        uint256 bkptPricePNS
    );
    event CantChangeCloseOrder(uint256 perpId, uint256 orderId, uint256 accountId);
    event CantDeleverageAgainstOpposingPositions(
        uint256 perpId,
        uint256 accountId,
        bool forceClose,
        PositionEnum positionType,
        uint256 deleveragePricePNS,
        uint256[] sortedPositionIds
    );
    event CantLiquidatePosAboveMMR(
        uint256 perpId, uint256 posAccountId, PositionEnum positionType, uint256 markPricePNS, uint256 liqPricePNS
    );
    event ChangeExpiredOrderNeedsNewExpiry(uint256 perpId, uint256 orderId, uint256 accountId, uint256 expiryBlock);
    event ClearedDecreaseCollatParams(uint256 perpId, uint256 accountId);
    event ClearingExpiredOrder(
        uint256 perpId,
        uint256 accountId,
        uint256 orderId,
        uint256 lockedBalanceCNS,
        uint256 recyclerAccountId,
        int256 recyclerAmountCNS,
        uint256 recyclerBalanceCNS
    );
    event ClearingFrozenAccountOrder(
        uint256 perpId,
        uint256 accountId,
        uint256 orderId,
        uint256 lockedBalanceCNS,
        uint256 recyclerAccountId,
        int256 recyclerAmountCNS,
        uint256 recyclerBalanceCNS
    );
    event ClearingInvalidCloseOrder(
        uint256 perpId,
        uint256 accountId,
        uint256 orderId,
        uint256 lockedBalanceCNS,
        uint256 recyclerAccountId,
        int256 recyclerAmountCNS,
        uint256 recyclerBalanceCNS
    );
    event ClearingSelfMatchingOrder(
        uint256 perpId,
        uint256 accountId,
        uint256 orderId,
        uint256 lockedBalanceCNS,
        uint256 recyclerAccountId,
        int256 recyclerAmountCNS,
        uint256 recyclerBalanceCNS
    );
    event CloseOrderExceedsPosition(uint256 posLotLNS, uint256 orderLotLNS);
    event CloseOrderPositionMismatch(PositionEnum positionType, OrderEnum orderType);
    event CollateralDecreaseApproved(
        uint256 perpId,
        uint256 accountId,
        uint256 expiryTS,
        uint256 impactAdjPricePNS,
        uint256 borrowMarginFracHdths,
        PositionEnum positionType
    );
    event CollateralDecreaseDeclined(uint256 perpId, uint256 accountId);
    event CollateralDecreaseRequested(
        uint256 perpId, uint256 accountId, PositionEnum positionType, uint256 entryPricePNS, uint256 lotLNS
    );
    event CollateralDeposit(uint256 accountId, uint256 amountCNS, uint256 balanceCNS);
    event CollateralWithdrawal(uint256 accountId, uint256 amountCNS, uint256 balanceCNS);
    event ContractAdded(
        uint256 perpId,
        string name,
        string symbol,
        bool paused,
        uint256 basePricePNS,
        uint256 priceDecimals,
        uint256 lotDecimals,
        uint256 takerFeePer100K,
        uint256 makerFeePer100K,
        uint256 initMarginFracHdths,
        uint256 maintMarginFracHdths,
        uint256 maxOpenInterestLNS,
        uint256 unityDescentThreshHdths,
        uint256 overColDescentThreshHdths,
        uint256 dcpBorrowThreshHdths,
        uint256 priceTolPer100K,
        uint256 refPriceMaxAgeSec,
        uint256 absFundingClampPctPer100K,
        uint256 permCancelMinOrders,
        uint256 permCancelSegment,
        uint256 insAmtPer100K,
        uint256 liqInsAmtPer100K,
        uint256 liqUserAmtPer100K,
        bool btlRestrictBuyers,
        uint256 btlPriceThreshPer100K,
        uint256 btlInsAmtPer100K,
        uint256 btlUserAmtPer100K,
        uint256 btlBuyerAmtPer100K,
        uint256 numPerpetuals
    );
    event ContractIsPaused(uint256 perpId);
    event ContractLinkFeedUpdated(uint256 perpId, bytes32 feedId);
    event ContractPaused(uint256 perpId, bool paused);
    event ContractRemoved(uint256 perpId);
    event CrossesBook(uint256 minAskOrMaxBidPNS, bool maxOrdersChecked);
    event DcpBorrowThreshUpdated(uint256 perpId, uint256 threshHdths);
    event DecreaseCollateralBeyondMarkPrice(
        uint256 perpId, uint256 accountId, PositionEnum positionType, uint256 impactAdjPricePNS, uint256 markPricePNS
    );
    event DecreaseCollateralParamsExpired(uint256 perpId, uint256 accountId, uint256 expiryTS, uint256 blockTS);
    event DeleveragePositionListEmpty(uint256 perpId, uint256 accountId);
    event ExceedsLastExecutionBlock(uint256 lastExecutionBlock);
    event ExchangeHalted(bool halted);
    event ExchangeInitialized(
        address sender,
        address collateralToken,
        uint256 collateralDecimals,
        uint256 minAccountOpenCNS,
        uint256 wrlsThousandthsTvl,
        uint256 wrlsMinWithdrawLimitCNS,
        uint256 recycleFeeCNS,
        bool whitelistingEnabled
    );
    event FeeParamsUpdated(uint256 perpId, uint256 insAmtPer100K);
    event FundingClampPctUpdated(uint256 perpId, uint256 clampPctPer100k);
    event FundingEventCompleted(
        uint256 perpId,
        uint256 fundingEventBlock,
        int256 specifiedRatePct100k,
        int256 actualRatePct100k,
        uint256 fundingPricePNS,
        int48 fundingPaymentPNS,
        int48 fundingSumPNS,
        bool allowOverwrite
    );
    event FundingEventSetTooEarly(uint256 perpId, uint256 blockNumber, uint256 fundingEventBlock);
    event FundingPriceExceedsTol(uint256 perpId, uint256 fundingPricePNS, uint256 oraclePNS, uint256 tolerancePer100k);
    event FundingSumAlreadySet(
        uint256 perpId, uint256 fundingEventBlock, uint256 storageIndex, uint256 fundingSumOffset
    );
    event IgnoreOracleUpdated(uint256 perpId, bool ignOracle);
    event ImmediateOrCancelExecuted(uint256 unmatchedLotLNS, uint256 totalLotLNS);
    event IncreasePositionCollateral(
        uint256 perpId, uint256 accountId, uint256 positionDepositCNS, uint256 amountCNS, uint256 balanceCNS
    );
    event InitialMarginFractionUpdated(uint256 perpId, uint256 initMarginFracHdths);
    event Initialized(uint8 version);
    event InsolventPositionCannotBeForcedClose(
        uint256 perpId,
        uint256 posAccountId,
        PositionEnum positionType,
        uint256 bankruptcyPricePNS,
        uint256 markPricePNS
    );
    event InsufficientFundsToDecCollateral(
        uint256 perpId, uint256 accountId, uint256 amountCNS, uint256 withdrawMaxCNS
    );
    event InsuficientFundsForRecycleFee(
        uint256 perpId, uint256 accountId, uint256 balanceCNS, uint256 lockedCNS, uint256 recycleFeeCNS
    );
    event InsurancePaymentForSettlement(uint256 perpId, uint256 accountId, uint256 insPaymentCNS);
    event InvalidAccountFrozenOrder(OrderDescEnum orderType, bool immediateOrCancel);
    event InvalidBankruptcyPrice(
        uint256 perpId,
        uint256 accountId,
        uint256 depositCNS,
        uint256 posPricePNS,
        uint256 liqLotLNS,
        int256 premiumPnlCNS
    );
    event InvalidExpiryBlock(uint256 expiryBlock, uint256 blockNumber);
    event InvalidLinkReportForContract(uint256 perpId, bytes32 perpFeedId, bytes32 reportFeedId);
    event InvalidLinkReportVersion(uint256 perpId, uint256 reportVersion);
    event InvalidLiquidationPrice(
        uint256 perpId,
        uint256 accountId,
        uint256 depositCNS,
        uint256 posPricePNS,
        uint256 liqLotLNS,
        int256 premiumPnlCNS
    );
    event InvalidOrderId(uint256 orderId, uint256 min, uint256 max);
    event LastForwardedDescIdReset(uint256 accountId, uint256 newDescId);
    event LinkDatastreamConfigured(address verifierProxy);
    event LinkDsError(uint256 perpId, bytes lowLevelData);
    event LinkDsError(uint256 perpId, string reason);
    event LinkDsPanic(uint256 perpId, uint256 errorCode);
    event LinkPriceUpdated(uint256 perpId, uint256 oraclePricePNS, uint256 timestamp);
    event LiquidationBuyerUpdated(address liquidationBuyer, uint256 accountId, bool added);
    event LiquidationParamsUpdated(
        uint256 perpId, uint256 insAmtPer100K, uint256 liqAmtPer100K, uint256 userAmtPer100K
    );
    event LotOutOfRange(uint256 minLotLNS, uint256 maxLotLNS);
    event MaintenanceMarginFractionUpdated(uint256 perpId, uint256 maintMarginFracHdths);
    event MakerFeeUpdated(uint256 perpId, uint256 makerFeePer100K);
    event MakerOrderFilled(
        uint256 perpId,
        uint256 accountId,
        uint256 orderId,
        uint256 pricePNS,
        uint256 lotLNS,
        uint256 feeCNS,
        uint256 lockedBalanceCNS,
        int256 amountCNS,
        uint256 balanceCNS
    );
    event MakerOrderSettlementFailed(
        uint256 perpId,
        uint256 accountId,
        uint256 orderId,
        OrderEnum orderType,
        uint256 pricePNS,
        uint256 lotLNS,
        uint256 reason,
        uint256 lockedBalanceCNS,
        uint256 recyclerAccountId,
        int256 recyclerAmountCNS,
        uint256 recyclerBalanceCNS
    );
    event MarkExceedsTol(uint256 perpId, uint256 markPNS, uint256 spotOraclePricePNS, uint256 tolerancePer100k);
    event MarkPriceAgeExceedsMax(uint256 perpId, uint256 markTimestamp, uint256 timestamp, uint256 maxAgeSec);
    event MarkUpdated(uint256 perpId, uint256 pricePNS);
    event MaxMatchesReached();
    event MaxOpenInterestUpdated(uint256 perpId, uint256 maxOpenInterestLNS);
    event MaximumAccountOrders(uint256 perpId, uint256 accountId);
    event MinAccountOpenAmountUpdated(uint256 minAccountOpenCNS);
    event MinPostUpdated(uint256 minPostCNS);
    event MinSettleUpdated(uint256 minSettleCNS);
    event OracleAgeExceedsMax(uint256 perpId, uint256 oracleTimestamp, uint256 timestamp, uint256 maxAgeSec);
    event OracleDisabled(uint256 perpId);
    event OrderBatchCompleted(uint256 gasLeft);
    event OrderCancelled(uint256 lockedBalanceCNS, int256 amountCNS, uint256 balanceCNS);
    event OrderCancelledByAdmin(uint256 perpId, uint256 accountId, uint256 orderId, uint256 lockedBalanceCNS);
    event OrderCancelledByLiquidator(uint256 perpId, uint256 accountId, uint256 orderId, uint256 lockedBalanceCNS);
    event OrderChanged(
        uint256 orderId,
        uint256 pricePNS,
        uint256 lotLNS,
        uint256 expiryBlock,
        uint256 lockedBalanceCNS,
        uint256 balanceCNS
    );
    event OrderDescIdTooLow(uint256 lastOrderDescId);
    event OrderDoesNotExist(uint256 perpId, uint256 orderId);
    event OrderForwardingNotAllowed();
    event OrderForwardingUpdated(uint256 accountId, bool allowed);
    event OrderPlaced(uint256 orderId, uint256 lotLNS, uint256 lockedBalanceCNS, int256 amountCNS, uint256 balanceCNS);
    event OrderPostFailed(uint256 reason);
    event OrderRequest(
        uint256 perpId,
        uint256 accountId,
        uint256 orderDescId,
        uint256 orderId,
        OrderDescEnum orderType,
        uint256 pricePNS,
        uint256 lotLNS,
        uint256 expiryBlock,
        bool postOnly,
        bool fillOrKill,
        bool immediateOrCancel,
        uint256 maxMatches,
        uint256 leverageHdths,
        uint256 lastExecutionBlock,
        uint256 amountCNS,
        uint256 gasLeft
    );
    event OrderSettlementImpliesInsolvent(
        uint256 perpId,
        uint256 accountId,
        OrderEnum orderType,
        uint256 pricePNS,
        uint256 lotLNS,
        uint256 perpPositionBalCNS,
        uint256 perpInsuranceBalCNS,
        uint256 addedPosCollatReqCNS,
        uint256 requestedAmountCNS
    );
    event OrderSizeExceedsAvailableSize(uint256 orderLotLNS, uint256 availableLotLNS, uint256 positionLotLNS);
    event OverCollatDescentThreshUpdated(uint256 perpId, uint256 threshHdths);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PermissonedCancelParamsUpdated(uint256 cancelMinOrders, uint256 cancelSegment);
    event PositionAdministratorUpdated(address positionAdministrator, bool added);
    event PositionClosed(
        uint256 perpId,
        uint256 accountId,
        PositionEnum positionType,
        uint256 pricePNS,
        int256 deltaPnlCNS,
        int256 fundingCNS
    );
    event PositionCollateralDecreased(
        uint256 perpId,
        uint256 accountId,
        PositionEnum positionType,
        uint256 markPricePNS,
        uint256 impactAdjPricePNS,
        uint256 startDepositCNS,
        uint256 endDepositCNS,
        uint256 startEntryPricePNS,
        uint256 endEntryPricePNS,
        uint256 effBmfHdths,
        uint256 decreaseCNS
    );
    event PositionDecreased(
        uint256 perpId,
        uint256 accountId,
        PositionEnum positionType,
        uint256 startDepositCNS,
        uint256 endDepositCNS,
        uint256 startLotLNS,
        uint256 endLotLNS,
        int256 deltaPnlCNS,
        int256 fundingCNS
    );
    event PositionDeleveraged(
        uint256 perpId,
        uint256 accountId,
        bool forceClose,
        PositionEnum positionType,
        uint256 entryPricePNS,
        uint256 markPricePNS,
        uint256 deleveragePricePNS,
        int256 deltaPnlCNS,
        int256 fundingCNS,
        uint256 startDepositCNS,
        uint256 endDepositCNS,
        uint256 startLotLNS,
        uint256 endLotLNS,
        uint256 amountCNS,
        uint256 balanceCNS
    );
    event PositionDoesNotExist(uint256 perpId, uint256 accountId);
    event PositionIncreased(
        uint256 perpId,
        uint256 accountId,
        PositionEnum positionType,
        uint256 leverageHdths,
        uint256 startDepositCNS,
        uint256 endDepositCNS,
        uint256 pricePNS,
        uint256 startLotLNS,
        uint256 endLotLNS,
        uint256 insFeeCNS,
        uint256 protFeeCNS
    );
    event PositionInverted(
        uint256 perpId,
        uint256 accountId,
        PositionEnum positionType,
        uint256 leverageHdths,
        uint256 startDepositCNS,
        uint256 endDepositCNS,
        uint256 pricePNS,
        uint256 startLotLNS,
        uint256 endLotLNS,
        int256 deltaPnlCNS,
        int256 fundingCNS,
        uint256 insFeeCNS,
        uint256 protFeeCNS
    );
    event PositionLiquidated(
        uint256 perpId,
        uint256 posAccountId,
        PositionEnum positionType,
        uint256 markPricePNS,
        uint256 liqPricePNS,
        uint256 liqLotLNS,
        uint256 posLotLNS,
        int256 deltaPnlCNS,
        int256 fundingCNS,
        int256 posAmountCNS,
        uint256 posDepositCNS,
        int256 accAmountCNS,
        uint256 accBalanceCNS,
        bool onOrderBook
    );
    event PositionLiquidationCredit(uint256 perpId, uint256 accountId, uint256 startDepositCNS, uint256 endDepositCNS);
    event PositionOpened(
        uint256 perpId,
        uint256 accountId,
        PositionEnum positionType,
        uint256 leverageHdths,
        uint256 depositCNS,
        uint256 pricePNS,
        uint256 lotLNS,
        uint256 insFeeCNS,
        uint256 protFeeCNS
    );
    event PositionTypeMismatch(
        uint256 perpId, uint256 accountId, PositionEnum positionType, PositionEnum specifiedType
    );
    event PositionUnwound(
        uint256 perpId,
        uint256 accountId,
        uint256 markPricePNS,
        PositionEnum positionType,
        uint256 pricePNS,
        uint256 lotLNS,
        uint256 depositCNS,
        int256 positionFmvCNS,
        uint256 paymentCNS,
        uint256 balanceCNS
    );
    event PositionUnwoundWithoutPayment(
        uint256 perpId,
        uint256 accountId,
        uint256 markPricePNS,
        PositionEnum positionType,
        uint256 pricePNS,
        uint256 lotLNS,
        uint256 depositCNS,
        int256 positionFmvCNS,
        uint256 amountOwedCNS
    );
    event PostOrderUnderMinimum(uint256 orderAmountCNS, uint256 minAmountCNS);
    event PriceAdministratorUpdated(address priceAdministrator, bool added);
    event PriceMaxAgeUpdated(uint256 perpId, uint256 maxAgeSec);
    event PriceOutOfRange(uint256 minPricePNS, uint256 maxPricePNS);
    event PriceTolUpdated(uint256 perpId, uint256 tolPer100k);
    event ProtocolBalanceDeposit(uint256 amountCNS);
    event ProtocolBalanceWithdraw(uint256 amountCNS);
    event RecycleBalanceInsufficientSevere(
        uint256 accountId, uint256 orderId, uint256 recycleFeeCNS, uint256 recycleBalanceCNS
    );
    event RecycleFeeUpdated(uint256 recycleFeeCNS);
    event RecyleFeeToProtocol(uint256 orderId, uint256 recycleFeeCNS, uint256 recycleBalanceCNS);
    event ReportAgeExceedsLastUpdate(uint256 perpId, uint256 lastUpdateTimestamp, uint256 reportValidFromTimestamp);
    event ReportPriceIsNegative(uint256 perpId, int256 reportPrice);
    event TakerFeeUpdated(uint256 perpId, uint256 takerFeePer100K);
    event TakerOrderFilled(uint256 pricePNS, uint256 lotLNS, uint256 feeCNS, int256 amountCNS, uint256 balanceCNS);
    event ToleranceAdministratorUpdated(address toleranceAdministrator, bool added);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event TransferAccountToProtocol(uint256 accountId, uint256 amountCNS, uint256 balanceCNS);
    event TransferPerpInsToProtocol(uint256 perpId, uint256 amountCNS);
    event TransferProtocolToAccount(uint256 accountId, uint256 amountCNS, uint256 balanceCNS);
    event TransferProtocolToPerp(uint256 perpId, uint256 amountCNS, bool toInsuranceFund);
    event TransferProtocolToRecycleBal(uint256 amountCNS);
    event UnableToCancelOrder(uint256 perpId, uint256 orderId);
    event UnityDescentThreshUpdated(uint256 perpId, uint256 threshHdths);
    event UnspecifiedCollateral();
    event UnwindCompleted(uint256 perpId, uint256 positionsUnwound, uint256 perpPositionBalanceCNS);
    event UnwindInitializationCleared(uint256 perpId);
    event UnwindInitialized(uint256 perpId, uint256 sumPositiveFmvCNS);
    event UnwindInsufficientBalance(
        uint256 perpId, uint256 accountId, uint256 perpPositionBalanceCNS, uint256 paymentCNS
    );
    event UnwindIterationCompleted(uint256 perpId, uint256 positionsUnwound, uint256 perpPositionBalanceCNS);
    event UpdateOracleFailed(uint256 perpId);
    event Upgraded(address indexed implementation);
    event ValueOutOfRange(uint256 value, uint256 min, uint256 max);
    event WRLSMinWithdrawLimitUpdated(uint256 limitCNS);
    event WRLSThousandthsTvlUpdated(uint256 thousandthsTvl);
    event WhitelistAddress(address indexed addr, bool whitelisted);
    event WhitelistingEnabledChanged(bool enabled);
    event WithdrawRateLimitBypassSet(address indexed addr, bool enabled);
    event WithdrawRateLimitForceReset(uint256 newExpiryBlock, uint256 newLimitCNS, uint256 perBlockCNS);
    event WithdrawRateLimitReset(uint256 newExpiryBlock, uint256 newLimitCNS, uint256 perBlockCNS);
    event WrongAccountForOrder(uint256 perpId, uint256 orderId, uint256 accountId);
}
