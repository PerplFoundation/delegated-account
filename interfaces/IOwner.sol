// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IOwner {
    type FreezeStatusEnum is uint8;

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
    function clearInitUnwindContract(uint256 perpId) external;
    function depositToProtocol(uint256 amountCNS) external;
    function forceResetWithdrawRateLimit() external;
    function initUnwindContract(uint256 perpId, uint256 sumPositiveFmvCNS) external;
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function removeContract(uint256 perpId) external;
    function renounceOwnership() external;
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
    function setExchangeHalted(bool halted) external;
    function setFeeParams(uint256 perpId, uint256 insAmtPer100K) external;
    function setFreezeStatus(address account, FreezeStatusEnum status) external;
    function setFundingClampPct(uint256 perpId, uint256 absFundingClampPctPer100K) external;
    function setIgnOracle(uint256 perpId, bool ignOracle) external;
    function setInitialMarginFraction(uint256 perpId, uint256 initMarginFracHdths) external;
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
    function whitelisted(address) external view returns (bool);
    function whitelistingEnabled() external view returns (bool);
    function withdrawFromProtocol(uint256 amountCNS) external;
    function xferPerpInsToProtocol(uint256 perpId, uint256 amountCNS) external;
    function xferProtocolToAcct(uint256 accountId, uint256 amountCNS) external;
    function xferProtocolToPerp(uint256 perpId, uint256 amountCNS, bool insurance) external;
    function xferProtocolToRecycleBal(uint256 amountCNS) external;
}
