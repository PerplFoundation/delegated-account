// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IPriceAdmin {
    type OpDescEnum is uint8;

    struct OpDesc {
        uint256 opDescId;
        uint256 perpId;
        OpDescEnum opType;
        uint32 pricePNS;
        int256 fundingRatePct100k;
        bool allowOverwrite;
        bytes unverifiedReport;
    }

    function acceptOwnership() external;
    function addressBlocked(address) external view returns (bool);
    function execPerpOps(OpDesc[] memory operations) external;
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function renounceOwnership() external;
    function setFundingSum(
        uint256 perpId,
        int256 fundingRatePct100k,
        uint32 pricePNS,
        bool allowOverwrite,
        bool revertOnFail
    ) external;
    function transferOwnership(address newOwner) external;
    function updateMarkPricePNS(uint256 perpId, uint32 markPricePNS) external;
    function updateOraclePrice(uint256 perpId, bytes memory unverifiedReport) external;
    function whitelisted(address) external view returns (bool);
    function whitelistingEnabled() external view returns (bool);
}
