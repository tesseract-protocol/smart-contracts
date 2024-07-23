// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

struct CellPayload {
    Instructions instructions;
    uint256 hop;
}

struct Instructions {
    address receiver;
    bytes32 sourceBlockchainId;
    address sourcePrimaryFeeToken;
    uint256 rollbackTeleporterFee;
    Hop[] hops;
}

struct Hop {
    Action action;
    uint256 gasLimit;
    bytes trade;
    BridgePath bridgePath;
}

struct BridgePath {
    address bridgeSourceChain;
    address bridgeDestinationChain;
    address cellDestinationChain;
    bytes32 destinationBlockchainId;
    uint256 teleporterFee;
}

enum Action {
    Hop,
    HopAndCall,
    SwapAndHop,
    SwapAndTransfer
}

interface ICell {
    event CellReceivedTokens(
        bytes32 indexed sourceBlockchainID,
        address indexed sourceBridge,
        address indexed originSender,
        address token,
        uint256 amount
    );

    event InitiatedSwap(address indexed sender, address indexed tokenIn, uint256 amountIn);

    function crossChainSwap(address token, uint256 amount, Instructions calldata instructions) external;
}
