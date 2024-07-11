// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./IYakRouter.sol";

struct BridgePath {
    address from;
    address to;
    bytes32 destinationBlockchainId;
}

struct SwapData {
    address receiver;
    address executor;
    uint256 gasLimit;
    Trade trade;
    BridgePath[] bridgePath;
}
