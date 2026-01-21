// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IExchange {
    type FreezeStatusEnum is uint8;
    type OpDescEnum is uint8;
    type OrderDescEnum is uint8;
    type OrderEnum is uint8;
    type PositionEnum is uint8;

    struct AccountInfo {
        uint256 accountId;
        uint256 balanceCNS;
        uint256 lockedBalanceCNS;
        FreezeStatusEnum frozen;
        address accountAddr;
        PositionBitMap positions;
    }

    struct AdlDesc {
        uint256 perpId;
        uint256 posAccountId;
        uint256[] sortedPositionIds;
    }

    struct BuyToLiquidateDesc {
        uint256 perpId;
        uint256 posAccountId;
        uint256 lotLNS;
        uint256 leverageHdths;
        uint256 limitPricePNS;
    }

    struct DecreaseCollateralParams {
        uint32 expiryTS;
        uint32 impactAdjPricePNS;
        uint16 borrowMarginFracHdths;
        PositionEnum positionType;
    }

    struct FwdOrderDesc {
        uint256 accountId;
        uint256 feePer100K;
        OrderDesc orderDesc;
    }

    struct FznOrderDesc {
        uint256 accountId;
        OrderDesc orderDesc;
    }

    struct LiquidationDesc {
        uint256 perpId;
        uint256 posAccountId;
        uint256 lotLNS;
        bool userProceedsToPosition;
    }

    struct LiquidationInfo {
        uint256 liqInsAmtPer100K;
        uint256 liqUserAmtPer100K;
        uint256 liqProtocolAmtPer100K;
        uint256 btlPriceThreshPer100K;
        uint256 btlInsAmtPer100K;
        uint256 btlUserAmtPer100K;
        uint256 btlBuyerAmtPer100K;
        uint256 btlProtocolAmtPer100K;
        bool btlRestrictBuyers;
    }

    struct OpDesc {
        uint256 opDescId;
        uint256 perpId;
        OpDescEnum opType;
        uint32 pricePNS;
        int256 fundingRatePct100k;
        bool allowOverwrite;
        bytes unverifiedReport;
    }

    struct Order {
        uint32 accountId;
        OrderEnum orderType;
        uint24 priceONS;
        uint40 lotLNS;
        uint16 recycleFeeRaw;
        uint32 expiryBlock;
        uint16 leverageHdths;
        uint16 orderId;
        uint16 prevOrderId;
        uint16 nextOrderId;
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

    struct OrderLock {
        uint32 orderLockId;
        uint32 nextOrderLockId;
        uint32 prevOrderLockId;
        OrderEnum orderType;
        uint40 lotLNS;
        uint80 amountCNS;
    }

    struct OrderSignature {
        uint256 perpId;
        uint256 orderId;
    }

    struct PerpetualInfo {
        string name;
        string symbol;
        uint256 priceDecimals;
        uint256 lotDecimals;
        bytes32 linkFeedId;
        uint256 priceTolPer100K;
        uint256 refPriceMaxAgeSec;
        uint256 positionBalanceCNS;
        uint256 insuranceBalanceCNS;
        uint256 markPNS;
        uint256 markTimestamp;
        uint256 lastPNS;
        uint256 lastTimestamp;
        uint256 oraclePNS;
        uint256 oracleTimestampSec;
        uint256 longOpenInterestLNS;
        uint256 shortOpenInterestLNS;
        uint256 fundingStartBlock;
        int16 fundingRatePct100k;
        uint256 absFundingClampPctPer100K;
        bool paused;
        uint256 basePricePNS;
        uint256 maxBidPriceONS;
        uint256 minBidPriceONS;
        uint256 maxAskPriceONS;
        uint256 minAskPriceONS;
        uint256 numOrders;
        bool ignOracle;
    }

    struct PositionBitMap {
        uint256 bank1;
        uint256 bank2;
        uint256 bank3;
        uint256 bank4;
    }

    struct PositionInfo {
        uint256 accountId;
        uint256 nextNodeId;
        uint256 prevNodeId;
        PositionEnum positionType;
        uint256 depositCNS;
        uint256 pricePNS;
        uint256 lotLNS;
        uint256 entryBlock;
        int256 pnlCNS;
        int256 deltaPnlCNS;
        int256 premiumPnlCNS;
    }

    function acceptOwnership() external;
    function addContract(
        string memory name,
        string memory symbol,
        uint256 perpId,
        uint256 basePricePNS,
        uint256 priceDecimals,
        uint256 lotDecimals,
        uint256 takerFeePer100K,
        uint256 makerFeePer100K,
        uint256 initMarginFracHdths,
        uint256 maintMarginFracHdths
    ) external;
    function addressBlocked(address) external view returns (bool);
    function adminCancelOrders(OrderSignature[] memory signatures) external;
    function allowOrderForwarding(bool allow) external;
    function autoDeleverage(AdlDesc[] memory adlDescs, bool revertOnFail) external;
    function buyLiquidations(BuyToLiquidateDesc[] memory liquidationDescs, bool revertOnFail) external;
    function clearDecreaseCollatParams(uint256 perpId, uint256 accountId) external;
    function clearInitUnwindContract(uint256 perpId) external;
    function clearOrderSlots(uint256 perpId, uint256[] memory orderIds) external;
    function clearPricePointerSlots(uint256 perpId, uint256[] memory pricesONS) external;
    function createAccount(uint256 amountCNS) external returns (uint256 accountId);
    function declineDecreaseCollateral(uint256 perpId, uint256 accountId) external;
    function decreasePositionCollateral(uint256 perpId, uint256 amountCNS, bool clampToMaximum) external;
    function depositCollateral(uint256 amountCNS) external;
    function depositToProtocol(uint256 amountCNS) external;
    function execFwdPositionOps(FwdOrderDesc[] memory forwardedOrders)
        external
        returns (OrderSignature[] memory signatures);
    function execFznAccountPosOps(FznOrderDesc[] memory fznAccountCloseOrders) external;
    function execOrder(OrderDesc memory orderDesc) external returns (OrderSignature memory signature);
    function execOrders(OrderDesc[] memory orderDescs, bool revertOnFail)
        external
        returns (OrderSignature[] memory signatures);
    function execPerpOps(OpDesc[] memory operations) external;
    function forceClose(uint256 perpId, uint256 posAccountId, uint256[] memory sortedPositionIds, bool revertOnFail)
        external
        returns (bool success);
    function forceResetWithdrawRateLimit() external;
    function getAccountByAddr(address accountAddress) external view returns (AccountInfo memory accountInfo);
    function getAccountById(uint256 accountId) external view returns (AccountInfo memory accountInfo);
    function getDecreaseCollateralParams(uint256 accountId, uint256 perpId)
        external
        view
        returns (DecreaseCollateralParams memory dcp);
    function getExchangeInfo()
        external
        view
        returns (
            uint256 balanceCNS,
            uint256 protocolBalanceCNS,
            uint256 recycleBalanceCNS,
            uint256 collateralDecimals,
            address collateralToken,
            address verifierProxy
        );
    function getFundingInterval() external pure returns (uint256 fundingInterval);
    function getFundingSumAtBlock(uint256 perpId, uint256 blockNumber)
        external
        view
        returns (int48 fundingSumPNS, uint256 fundingEventBlock);
    function getLiquidationInfo(uint256 perpId) external view returns (LiquidationInfo memory liquidationInfo);
    function getMakerFee(uint256 perpId) external view returns (uint256);
    function getMarginFractions(uint256 perpId, uint256 lotLNS)
        external
        view
        returns (
            uint256 perpInitMarginFracHdths,
            uint256 perpMaintMarginFracHdths,
            uint256 dynamicInitMarginFracHdths,
            uint256 oiMaxLNS,
            uint256 unityDescentThreshHdths,
            uint256 overColDescentThreshHdths
        );
    function getMinAccountOpenCNS() external view returns (uint256 minAccountOpenCNS);
    function getMinimumPostCNS() external view returns (uint256 minimumPostCNS);
    function getMinimumSettleCNS() external view returns (uint256 minimumSettleCNS);
    function getNextPriceBelowWithOrders(uint256 perpId, uint256 priceONS) external view returns (uint256 priceBelowONS);
    function getOrder(uint256 perpId, uint256 orderId) external view returns (Order memory order);
    function getOrderIdIndex(uint256 perpId)
        external
        view
        returns (uint256 root, uint256[] memory leaves, uint256 numOrders);
    function getOrderLocks(uint256 accountId) external view returns (OrderLock[] memory orderLocks);
    function getOrdersAtPriceLevel(uint256 perpId, uint256 priceONS, uint256 pageStartOrderId, uint256 ordersPerPage)
        external
        view
        returns (Order[] memory ordersAtPriceLevel, uint256 numOrders);
    function getOwner() external view returns (address);
    function getPermissionedCancelParams(uint256 perpId)
        external
        view
        returns (uint256 permCancelMinOrders, uint256 permCancelSegment);
    function getPerpOrderLocks(uint256 accountId, uint256 perpId)
        external
        view
        returns (OrderLock[] memory perpOrderLocks);
    function getPerpetualInfo(uint256 perpId) external view returns (PerpetualInfo memory perpetualInfo);
    function getPosition(uint256 perpId, uint256 accountId)
        external
        view
        returns (PositionInfo memory positionInfo, uint256 markPricePNS, bool markPriceValid);
    function getPositionIds(uint256 perpId) external view returns (uint256 startNodeId, uint256 endNodeId);
    function getPositions(uint256 perpId, uint256 pageStartPositionId, uint256 positionsPerPage)
        external
        view
        returns (PositionInfo[] memory positions, uint256 numPositions, uint256 markPricePNS, bool markPriceValid);
    function getPriceLevelOrderIds(uint256 perpId, uint256 priceONS)
        external
        view
        returns (uint256 startOrderId, uint256 endOrderId);
    function getProtocolBalanceCNS() external view returns (uint256 protocolBalanceCNS);
    function getRecycleBalanceCNS() external view returns (uint256 recycleBalanceCNS);
    function getRecycleFeeCNS() external view returns (uint256 recycleFeeCNS);
    function getTakerFee(uint256 perpId) external view returns (uint256);
    function getUnwindInfo(uint256 perpId)
        external
        view
        returns (
            bool unwindInitialized,
            bool unwindStarted,
            uint256 unwindSumPositiveFmvCNS,
            uint256 unwindInitPosBalCNS
        );
    function getVolumeAtBookPrice(uint256 perpId, uint256 priceONS)
        external
        view
        returns (uint256 bids, uint256 expBids, uint256 asks, uint256 expAsks);
    function getWithdrawAllowanceData(uint256 blockNumber)
        external
        view
        returns (uint256 allowanceCNS, uint256 expiryBlock, uint256 lastAllowanceBlock, uint256 cnsPerBlock);
    function increasePositionCollateral(uint256 perpId, uint256 amountCNS) external;
    function initUnwindContract(uint256 perpId, uint256 sumPositiveFmvCNS) external;
    function initialize(address collateralToken) external;
    function isAdministrator(address anAddress) external view returns (bool);
    function isHalted() external view returns (bool halted);
    function isLiquidationBuyer(address anAddress) external view returns (bool);
    function isPositionAdministrator(address anAddress) external view returns (bool);
    function isPriceAdministrator(address anAddress) external view returns (bool);
    function isToleranceAdministrator(address anAddress) external view returns (bool);
    function liquidation(LiquidationDesc memory liquidationDesc) external;
    function liquidations(LiquidationDesc[] memory liquidationDescs, bool revertOnFail) external;
    function numberOfAccounts() external view returns (uint256 numAccounts);
    function owner() external view returns (address);
    function pauseContract(uint256 perpId) external;
    function pendingOwner() external view returns (address);
    function proxiableUUID() external view returns (bytes32);
    function removeContract(uint256 perpId) external;
    function renounceOwnership() external;
    function requestDecreasePositionCollateral(uint256 perpId) external;
    function setAddressBlockStatus(address[] memory addresses, bool blocked) external;
    function setAddressWhitelisted(address[] memory addresses, bool whitelisted_) external;
    function setAdministrator(address administrator, bool add) external;
    function setBuyToLiquidateBuyerRestriction(uint256 perpId, bool restrictBuyers) external;
    function setBuyToLiquidateParams(
        uint256 perpId,
        uint256 insAmtPer100K,
        uint256 userAmtPer100K,
        uint256 buyerAmtPer100K
    ) external;
    function setBuyToLiquidatePriceThreshold(uint256 perpId, uint256 thresholdPer100K) external;
    function setContractPaused(uint256 perpId, bool paused) external;
    function setDcpBorrowThreshold(uint256 perpId, uint256 threshHdths) external;
    function setDecreaseCollatParams(
        uint256 perpId,
        uint256 accountId,
        uint32 expiryTS,
        uint32 impactAdjPricePNS,
        uint16 borrowMarginFracHdths,
        PositionEnum positionType
    ) external;
    function setExchangeHalted(bool halted) external;
    function setFeeParams(uint256 perpId, uint256 insAmtPer100K) external;
    function setFreezeStatus(address account, FreezeStatusEnum status) external;
    function setFrozen(address account, FreezeStatusEnum status) external;
    function setFundingClampPct(uint256 perpId, uint256 absFundingClampPctPer100K) external;
    function setFundingSum(
        uint256 perpId,
        int256 fundingRatePct100k,
        uint32 pricePNS,
        bool allowOverwrite,
        bool revertOnFail
    ) external;
    function setIgnOracle(uint256 perpId, bool ignOracle) external;
    function setInitialMarginFraction(uint256 perpId, uint256 initMarginFracHdths) external;
    function setLastForwardedDescId(uint256 accountId, uint256 newDescId) external;
    function setLastForwardedDescIdAsOwner(uint256 accountId, uint256 newDescId) external;
    function setLinkDsVerifier(address verifierProxy) external;
    function setLiquidationBuyer(address liquidationBuyer, bool add) external;
    function setLiquidationParams(uint256 perpId, uint256 insAmtPer100K, uint256 userAmtPer100K) external;
    function setMaintenanceMarginFraction(uint256 perpId, uint256 maintMarginFracHdths) external;
    function setMakerFee(uint256 perpId, uint256 makerFeePer100K) external;
    function setMaxOpenInterest(uint256 perpId, uint256 maxOpenInterestLNS) external;
    function setMinAccountOpenAmount(uint256 amountCNS) external;
    function setMinPost(uint256 minPostCNS) external;
    function setMinSettle(uint256 minSettleCNS) external;
    function setMinWithdrawLimit(uint256 limitCNS) external;
    function setOverCollatDescentThreshold(uint256 perpId, uint256 threshHdths) external;
    function setPermissionedCancelParams(uint256 perpId, uint256 permCancelMinOrders, uint256 permCancelSegment)
        external;
    function setPerpLinkDsFeedId(uint256 perpId, bytes32 feedId) external;
    function setPositionAdministrator(address positionAdministrator, bool add) external;
    function setPriceAdministrator(address priceAdministrator, bool add) external;
    function setPriceMaxAge(uint256 perpId, uint256 maxAgeSec) external;
    function setPriceTolPer100K(uint256 perpId, uint256 tolerancePer100K) external;
    function setPriceTolPer100KByOwner(uint256 perpId, uint256 tolerancePer100K) external;
    function setRecycleFee(uint256 recycleFeeCNS) external;
    function setTakerFee(uint256 perpId, uint256 takerFeePer100K) external;
    function setThousandthsTvlWRLS(uint256 thousandthsTvl) external;
    function setToleranceAdministrator(address toleranceAdministrator, bool add) external;
    function setUnityDescentThreshold(uint256 perpId, uint256 threshHdths) external;
    function setWhitelistingEnabled(bool enabled) external;
    function setWithdrawBypass(address addr, bool enabled) external;
    function transferOwnership(address newOwner) external;
    function unwindContract(uint256 perpId, uint256 maxPosToUnwind, bool allowWithoutPayment) external;
    function updateMarkPricePNS(uint256 perpId, uint32 markPricePNS) external;
    function updateOraclePrice(uint256 perpId, bytes memory unverifiedReport) external;
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
    function whitelisted(address) external view returns (bool);
    function whitelistingEnabled() external view returns (bool);
    function withdrawCollateral(uint256 amountCNS) external;
    function withdrawFromProtocol(uint256 amountCNS) external;
    function xferAcctToProtocol(uint256 amountCNS) external;
    function xferPerpInsToProtocol(uint256 perpId, uint256 amountCNS) external;
    function xferProtocolToAcct(uint256 accountId, uint256 amountCNS) external;
    function xferProtocolToPerp(uint256 perpId, uint256 amountCNS, bool insurance) external;
    function xferProtocolToRecycleBal(uint256 amountCNS) external;
}
