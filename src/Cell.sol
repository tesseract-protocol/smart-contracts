// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./interfaces/ICell.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@avalanche-interchain-token-transfer/interfaces/IERC20TokenTransferrer.sol";
import "@teleporter/upgrades/TeleporterRegistry.sol";
import "@avalanche-interchain-token-transfer/interfaces/IERC20SendAndCallReceiver.sol";

abstract contract Cell is ICell, IERC20SendAndCallReceiver {
    using SafeERC20 for IERC20;

    uint256 constant GAS_LIMIT_BRIDGE_HOP = 350_000;

    TeleporterRegistry public immutable teleporterRegistry;
    address public immutable primaryFeeToken;

    constructor(address teleporterRegistryAddress, address primaryFeeTokenAddress) {
        require(teleporterRegistryAddress > address(0), "Cell: invalid teleporter registry address");

        teleporterRegistry = TeleporterRegistry(teleporterRegistryAddress);
        primaryFeeToken = primaryFeeTokenAddress;
    }

    /* Entry Points */

    function crossChainSwap(address token, uint256 amount, Instructions calldata instructions) external override {
        emit InitiatedSwap(msg.sender, token, amount);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        CellPayload memory payload = CellPayload({instructions: instructions, hop: 0});
        _route(token, amount, payload);
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
        _route(token, amount, cellPayload);
    }

    /* Internal Functions */

    function _route(address token, uint256 amount, CellPayload memory payload) internal {
        Hop memory hop = payload.instructions.hops[payload.hop];
        if (hop.action == Action.Hop) {
            _send(token, amount, payload);
        } else if (hop.action == Action.HopAndCall) {
            _sendAndCall(token, amount, payload);
        } else if (hop.action == Action.SwapAndHop) {
            (address tokenOut, uint256 amountOut) = _swap(token, amount, payload);
            if (payload.hop == payload.instructions.hops.length - 1) {
                _send(tokenOut, amountOut, payload);
            } else {
                _sendAndCall(tokenOut, amountOut, payload);
            }
        } else if (hop.action == Action.SwapAndTransfer) {
            (address tokenOut, uint256 amountOut) = _swap(token, amount, payload);
            IERC20(tokenOut).safeTransfer(payload.instructions.receiver, amountOut);
        }
    }

    function _swap(address token, uint256 amount, CellPayload memory payload)
        internal
        virtual
        returns (address tokenOut, uint256 amountOut);

    function _sendAndCall(address token, uint256 amount, CellPayload memory payload) internal {
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
        IERC20(hop.bridgePath.bridgeSourceChain).approve(token, amount);
        IERC20TokenTransferrer(hop.bridgePath.bridgeSourceChain).sendAndCall(input, amount);
    }

    function _send(address token, uint256 amount, CellPayload memory payload) internal {
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
        IERC20(token).approve(hop.bridgePath.bridgeSourceChain, amount);
        IERC20TokenTransferrer(hop.bridgePath.bridgeSourceChain).send(input, amount);
    }
}
