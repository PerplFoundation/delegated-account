// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IPositionAdmin {
    type OrderDescEnum is uint8;
    type PositionEnum is uint8;

    struct AdlDesc {
        uint256 perpId;
        uint256 posAccountId;
        uint256[] sortedPositionIds;
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

    function acceptOwnership() external;
    function addressBlocked(address) external view returns (bool);
    function autoDeleverage(AdlDesc[] memory adlDescs, bool revertOnFail) external;
    function clearDecreaseCollatParams(uint256 perpId, uint256 accountId) external;
    function declineDecreaseCollateral(uint256 perpId, uint256 accountId) external;
    function execFznAccountPosOps(FznOrderDesc[] memory fznAccountCloseOrders) external;
    function forceClose(uint256 perpId, uint256 posAccountId, uint256[] memory sortedPositionIds, bool revertOnFail)
        external
        returns (bool success);
    function liquidation(LiquidationDesc memory liquidationDesc) external;
    function liquidations(LiquidationDesc[] memory liquidationDescs, bool revertOnFail) external;
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function renounceOwnership() external;
    function setDecreaseCollatParams(
        uint256 perpId,
        uint256 accountId,
        uint32 expiryTS,
        uint32 impactAdjPricePNS,
        uint16 borrowMarginFracHdths,
        PositionEnum positionType
    ) external;
    function transferOwnership(address newOwner) external;
    function whitelisted(address) external view returns (bool);
    function whitelistingEnabled() external view returns (bool);
}
