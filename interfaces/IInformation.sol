// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IInformation {
    type FreezeStatusEnum is uint8;
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

    struct DecreaseCollateralParams {
        uint32 expiryTS;
        uint32 impactAdjPricePNS;
        uint16 borrowMarginFracHdths;
        PositionEnum positionType;
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

    struct OrderLock {
        uint32 orderLockId;
        uint32 nextOrderLockId;
        uint32 prevOrderLockId;
        OrderEnum orderType;
        uint40 lotLNS;
        uint80 amountCNS;
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
    function addressBlocked(address) external view returns (bool);
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
    function isAdministrator(address anAddress) external view returns (bool);
    function isHalted() external view returns (bool halted);
    function isLiquidationBuyer(address anAddress) external view returns (bool);
    function isPositionAdministrator(address anAddress) external view returns (bool);
    function isPriceAdministrator(address anAddress) external view returns (bool);
    function isToleranceAdministrator(address anAddress) external view returns (bool);
    function numberOfAccounts() external view returns (uint256 numAccounts);
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function renounceOwnership() external;
    function transferOwnership(address newOwner) external;
    function whitelisted(address) external view returns (bool);
    function whitelistingEnabled() external view returns (bool);
}
