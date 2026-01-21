// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IAdmin {
    type FreezeStatusEnum is uint8;
    type OrderDescEnum is uint8;

    struct FwdOrderDesc {
        uint256 accountId;
        uint256 feePer100K;
        OrderDesc orderDesc;
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
    function adminCancelOrders(OrderSignature[] memory signatures) external;
    function clearOrderSlots(uint256 perpId, uint256[] memory orderIds) external;
    function clearPricePointerSlots(uint256 perpId, uint256[] memory pricesONS) external;
    function execFwdPositionOps(FwdOrderDesc[] memory forwardedOrders)
        external
        returns (OrderSignature[] memory signatures);
    function owner() external view returns (address);
    function pauseContract(uint256 perpId) external;
    function pendingOwner() external view returns (address);
    function renounceOwnership() external;
    function setAddressBlockStatus(address[] memory addresses, bool blocked) external;
    function setAddressWhitelisted(address[] memory addresses, bool whitelisted_) external;
    function setFrozen(address account, FreezeStatusEnum status) external;
    function setLastForwardedDescId(uint256 accountId, uint256 newDescId) external;
    function transferOwnership(address newOwner) external;
    function whitelisted(address) external view returns (bool);
    function whitelistingEnabled() external view returns (bool);
}
