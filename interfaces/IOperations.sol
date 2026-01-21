// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IOperations {
    type OrderDescEnum is uint8;

    struct BuyToLiquidateDesc {
        uint256 perpId;
        uint256 posAccountId;
        uint256 lotLNS;
        uint256 leverageHdths;
        uint256 limitPricePNS;
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

    function acceptOwnership() external;
    function addressBlocked(address) external view returns (bool);
    function buyLiquidations(BuyToLiquidateDesc[] memory liquidationDescs, bool revertOnFail) external;
    function decreasePositionCollateral(uint256 perpId, uint256 amountCNS, bool clampToMaximum) external;
    function execOrder(OrderDesc memory orderDesc) external returns (OrderSignature memory signature);
    function execOrders(OrderDesc[] memory orderDescs, bool revertOnFail)
        external
        returns (OrderSignature[] memory signatures);
    function increasePositionCollateral(uint256 perpId, uint256 amountCNS) external;
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function renounceOwnership() external;
    function requestDecreasePositionCollateral(uint256 perpId) external;
    function transferOwnership(address newOwner) external;
    function whitelisted(address) external view returns (bool);
    function whitelistingEnabled() external view returns (bool);
}
