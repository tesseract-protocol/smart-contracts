// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./interfaces/ISwapData.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@avalanche-interchain-token-transfer/interfaces/IERC20TokenTransferrer.sol";
import "teleporter/contracts/src/Teleporter/upgrades/TeleporterRegistry.sol";
import "avalanche-interchain-token-transfer/contracts/src/interfaces/IERC20SendAndCallReceiver.sol";

contract Cell is IERC20SendAndCallReceiver {
    using SafeERC20 for IERC20;

    uint256 constant GAS_LIMIT_BRIDGE_HOP = 350_000;

    TeleporterRegistry public immutable teleporterRegistry;
    IYakRouter public immutable router;
    address public immutable primaryFeeToken;

    event CellReceivedTokens(
        bytes32 indexed sourceBlockchainID,
        address indexed sourceBridge,
        address indexed originSender,
        address token,
        uint256 amount
    );

    event InitiatedSwap(address indexed sender, address indexed tokenIn, uint256 amountIn);

    constructor(address teleporterRegistryAddress, address routerAddress, address primaryFeeTokenAddress) {
        require(teleporterRegistryAddress > address(0), "Cell: invalid teleporter registry address");

        teleporterRegistry = TeleporterRegistry(teleporterRegistryAddress);
        router = IYakRouter(routerAddress);
        primaryFeeToken = primaryFeeTokenAddress;
    }

    /* Entry Points */

    function crossChainSwap(Instructions calldata instructions) external {
        emit InitiatedSwap(msg.sender, instructions.hops[0].tokenIn, instructions.hops[0].amountIn);
        IERC20(instructions.hops[0].tokenIn).safeTransferFrom(msg.sender, address(this), instructions.hops[0].amountIn);
        CellPayload memory payload = CellPayload({instructions: instructions, hop: 0});
        _route(payload);
    }

    function receiveTokens(
        bytes32 sourceBlockchainID,
        address originTokenTransferrerAddress,
        address originSenderAddress,
        address token,
        uint256 amount,
        bytes calldata payload
    ) external override {
        emit CellReceivedTokens(sourceBlockchainID, originTokenTransferrerAddress, originSenderAddress, token, amount);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        CellPayload memory cellPayload = abi.decode(payload, (CellPayload));
        cellPayload.hop++;
        cellPayload.instructions.hops[cellPayload.hop].tokenIn = token;
        cellPayload.instructions.hops[cellPayload.hop].amountIn = amount;
        _route(cellPayload);
    }

    /* Internal Functions */

    function _route(CellPayload memory payload) internal {
        Hop memory hop = payload.instructions.hops[payload.hop];
        if (hop.action == Action.Hop) {
            _send(payload);
        } else if (hop.action == Action.HopAndCall) {
            _sendAndCall(payload);
        } else if (hop.action == Action.SwapAndHop) {
            _swap(payload);
            if (payload.hop == payload.instructions.hops.length - 1) {
                _send(payload);
            } else {
                _sendAndCall(payload);
            }
        } else if (hop.action == Action.SwapAndTransfer) {
            uint256 amountOut = _swap(payload);
            address tokenOut = hop.trade.path[hop.trade.path.length - 1];
            IERC20(tokenOut).safeTransfer(payload.instructions.receiver, amountOut);
        }
    }

    function _swap(CellPayload memory payload) internal returns (uint256 amountOut) {
        Trade memory trade = payload.instructions.hops[payload.hop].trade;
        address tokenOut = trade.path[trade.path.length - 1];
        uint256 balanceBefore = IERC20(tokenOut).balanceOf(address(this));
        IERC20(payload.instructions.hops[payload.hop].tokenIn).approve(
            address(router), payload.instructions.hops[payload.hop].amountIn
        );
        IYakRouter(router).swapNoSplit(trade, address(this), 0);
        payload.instructions.hops[payload.hop].tokenIn = tokenOut;
        payload.instructions.hops[payload.hop].amountIn = IERC20(tokenOut).balanceOf(address(this)) - balanceBefore;
    }

    function _sendAndCall(CellPayload memory payload) internal {
        Hop memory hop = payload.instructions.hops[payload.hop];
        SendAndCallInput memory input = SendAndCallInput({
            destinationBlockchainID: hop.bridgePath.destinationBlockchainId,
            destinationTokenTransferrerAddress: hop.bridgePath.bridgeDestinationChain,
            recipientContract: hop.bridgePath.cellDestinationChain,
            recipientPayload: abi.encode(payload),
            requiredGasLimit: hop.gasLimit + GAS_LIMIT_BRIDGE_HOP,
            recipientGasLimit: hop.gasLimit,
            multiHopFallback: address(0),
            fallbackRecipient: msg.sender,
            primaryFeeTokenAddress: primaryFeeToken,
            primaryFee: 0,
            secondaryFee: 0
        });
        IERC20(hop.bridgePath.bridgeSourceChain).approve(hop.tokenIn, hop.amountIn);
        IERC20TokenTransferrer(hop.bridgePath.bridgeSourceChain).sendAndCall(input, hop.amountIn);
    }

    function _send(CellPayload memory payload) internal {
        Hop memory hop = payload.instructions.hops[payload.hop];
        SendTokensInput memory input = SendTokensInput({
            destinationBlockchainID: hop.bridgePath.destinationBlockchainId,
            destinationTokenTransferrerAddress: hop.bridgePath.bridgeDestinationChain,
            recipient: payload.instructions.receiver,
            primaryFeeTokenAddress: primaryFeeToken,
            primaryFee: 0,
            secondaryFee: 0,
            requiredGasLimit: GAS_LIMIT_BRIDGE_HOP,
            multiHopFallback: address(0)
        });
        IERC20(hop.tokenIn).approve(hop.bridgePath.bridgeSourceChain, hop.amountIn);
        IERC20TokenTransferrer(hop.bridgePath.bridgeSourceChain).send(input, hop.amountIn);
    }
}
