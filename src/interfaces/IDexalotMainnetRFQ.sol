// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IDexalotMainnetRFQ {
    struct Order {
        uint256 nonceAndMeta;
        uint128 expiry;
        address makerAsset;
        address takerAsset;
        address maker;
        address taker;
        uint256 makerAmount;
        uint256 takerAmount;
    }

    function simpleSwap(Order calldata order, bytes calldata signature) external payable;
}
