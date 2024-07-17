// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./IYakRouter.sol";

struct CellPayload {
    Instructions instructions;
    uint256 hop;
}

struct Instructions {
    address receiver;
    Hop[] hops;
}

struct Hop {
    Action action;
    address tokenIn;
    uint256 amountIn;
    uint256 gasLimit;
    Trade trade;
    BridgePath bridgePath;
}

struct BridgePath {
    address bridgeSourceChain;
    address bridgeDestinationChain;
    address cellDestinationChain;
    bytes32 destinationBlockchainId;
}

enum Action {
    Hop,
    HopAndCall,
    SwapAndHop,
    SwapAndTransfer
}
