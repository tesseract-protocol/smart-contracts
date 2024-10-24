// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {ICell, CellPayload, Instructions, Hop, BridgePath, Action} from "./interfaces/ICell.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20TokenTransferrer} from "@avalanche-interchain-token-transfer/interfaces/IERC20TokenTransferrer.sol";
import {IERC20SendAndCallReceiver} from "@avalanche-interchain-token-transfer/interfaces/IERC20SendAndCallReceiver.sol";
import {
    SendAndCallInput, SendTokensInput
} from "@avalanche-interchain-token-transfer/interfaces/ITokenTransferrer.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {INativeTokenTransferrer} from "@avalanche-interchain-token-transfer/interfaces/INativeTokenTransferrer.sol";
import {INativeSendAndCallReceiver} from
    "@avalanche-interchain-token-transfer/interfaces/INativeSendAndCallReceiver.sol";
import {IWrappedNativeToken} from "@avalanche-interchain-token-transfer/interfaces/IWrappedNativeToken.sol";
import {TokenRemote} from "@avalanche-interchain-token-transfer/TokenRemote/TokenRemote.sol";
import {IWarpMessenger} from "@avalabs/subnet-evm-contracts@1.2.0/contracts/interfaces/IWarpMessenger.sol";

/**
 * @title Cell
 * @dev Abstract contract for facilitating cross-chain token swaps and transfers
 * This contract implements the core functionality for cross-chain operations,
 * including token swaps, transfers, and multi-hop transactions.
 */
abstract contract Cell is ICell, IERC20SendAndCallReceiver, INativeSendAndCallReceiver, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address payable;

    IWrappedNativeToken wrappedNativeToken;
    bytes32 public immutable blockchainID;

    constructor(address wrappedNativeTokenAddress) {
        wrappedNativeToken = IWrappedNativeToken(wrappedNativeTokenAddress);
        blockchainID = IWarpMessenger(0x0200000000000000000000000000000000000005).getBlockchainID();
    }

    /**
     * @dev Fallback function to receive native tokens
     * @notice Only accepts native tokens from the wrapped native token contract
     */
    receive() external payable {
        if (msg.sender != address(wrappedNativeToken)) revert InvalidSender();
    }

    /**
     * @notice Initiates a cross-chain swap
     * @param token The address of the token to be swapped/bridged
     * @param amount The amount of tokens to be swapped/bridged
     * @param instructions The instructions for the cross-chain swap
     */
    function initiate(address token, uint256 amount, Instructions calldata instructions)
        external
        override
        nonReentrant
    {
        if (amount == 0) {
            revert InvalidAmount();
        }
        emit Initiated(msg.sender, token, amount);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        CellPayload memory payload = CellPayload({
            instructions: instructions,
            rollbackDestination: instructions.hops[0].bridgePath.bridgeSourceChain,
            sourceBlockchainID: blockchainID
        });
        _route(token, amount, payload, address(0), false);
    }

    /**
     * @notice Receives tokens from another chain and processes them
     * @dev Handles the receipt of ERC20 tokens from cross-chain transfers
     * @param sourceBlockchainID The ID of the source blockchain
     * @param originTokenTransferrerAddress The address of the token transferrer on the origin chain
     * @param originSenderAddress The address of the sender on the origin chain
     * @param token The address of the received token
     * @param amount The amount of tokens received
     * @param payload The payload containing instructions for further processing
     */
    function receiveTokens(
        bytes32 sourceBlockchainID,
        address originTokenTransferrerAddress,
        address originSenderAddress,
        address token,
        uint256 amount,
        bytes calldata payload
    ) external override nonReentrant {
        emit CellReceivedTokens(sourceBlockchainID, originTokenTransferrerAddress, originSenderAddress, token, amount);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        _receiveTokens(sourceBlockchainID, originTokenTransferrerAddress, token, amount, false, payload);
    }

    /**
     * @notice Receives native tokens from another chain and processes them
     * @dev Handles the receipt of native tokens from cross-chain transfers.
     * The received native tokens are immediately wrapped into the equivalent ERC20 token
     * to streamline the routing process. This allows for consistent handling of both
     * native and non-native tokens in subsequent operations.
     * @param sourceBlockchainID The ID of the source blockchain
     * @param originTokenTransferrerAddress The address of the token transferrer on the origin chain
     * @param originSenderAddress The address of the sender on the origin chain
     * @param payload The payload containing instructions for further processing
     */
    function receiveTokens(
        bytes32 sourceBlockchainID,
        address originTokenTransferrerAddress,
        address originSenderAddress,
        bytes calldata payload
    ) external payable override {
        emit CellReceivedNativeTokens(sourceBlockchainID, originTokenTransferrerAddress, originSenderAddress);
        wrappedNativeToken.deposit{value: msg.value}();
        _receiveTokens(
            sourceBlockchainID, originTokenTransferrerAddress, address(wrappedNativeToken), msg.value, true, payload
        );
    }

    /**
     * @notice Internal function to process received tokens
     * @dev Decodes the payload and routes the tokens accordingly
     * @param sourceBlockchainID The ID of the source blockchain
     * @param originTokenTransferrerAddress The address of the token transferrer on the origin chain
     * @param token The address of the received token
     * @param amount The amount of tokens received
     * @param receivedNative Boolean indicating if native tokens were received
     * @param payload The payload containing instructions for further processing
     */
    function _receiveTokens(
        bytes32 sourceBlockchainID,
        address originTokenTransferrerAddress,
        address token,
        uint256 amount,
        bool receivedNative,
        bytes calldata payload
    ) internal {
        CellPayload memory cellPayload = abi.decode(payload, (CellPayload));
        address rollbackBridge = (
            sourceBlockchainID == cellPayload.sourceBlockchainID
                && originTokenTransferrerAddress == cellPayload.rollbackDestination
        ) ? msg.sender : address(0);
        _route(token, amount, cellPayload, rollbackBridge, receivedNative);
    }

    /**
     * @notice Calculates the route for a token swap
     * @dev This function should be implemented by the derived contract
     * @param amountIn The amount of input tokens
     * @param tokenIn The address of the input token
     * @param tokenOut The address of the output token
     * @param extras Additional data for routing
     * @return trade The encoded trade data
     * @return gasEstimate The estimated gas cost for the trade
     */
    function route(uint256 amountIn, address tokenIn, address tokenOut, bytes calldata extras)
        external
        view
        virtual
        returns (bytes memory trade, uint256 gasEstimate);

    /**
     * @notice Performs a token swap
     * @dev This function should be implemented by the derived contract.
     * IMPORTANT: This function should use proper exception handling to manage errors.
     * Use try/catch blocks to handle exceptions that may occur during the swap process.
     * Indicate success or failure through the success return parameter.
     * If an exception occurs or the swap fails for any reason:
     * 1. Catch the exception and handle it gracefully.
     * 2. Set success to false.
     * 3. Provide appropriate values for tokenOut (e.g., address(0)) and amountOut (e.g., 0).
     * 4. Optionally, emit an event with error details for off-chain tracking.
     * This approach allows the calling function to handle failed swaps gracefully,
     * potentially enabling rollbacks or other recovery mechanisms.
     * @param token The address of the input token
     * @param amount The amount of input tokens
     * @param tradePayload The payload containing swap instructions
     * @return success Whether the swap was successful (true) or failed (false)
     * @return tokenOut The address of the output token (or address(0) if swap failed)
     * @return amountOut The amount of output tokens (or 0 if swap failed)
     */
    function _swap(address token, uint256 amount, bytes memory tradePayload)
        internal
        virtual
        returns (bool success, address tokenOut, uint256 amountOut);

    /**
     * @notice Routes the tokens based on the provided payload
     * @dev Handles swapping, transferring, and sending tokens across chains
     * @param token The address of the token to route
     * @param amount The amount of tokens to route
     * @param payload The payload containing routing instructions
     * @param rollbackBridge The address of the bridge to use for rollbacks
     * @param rollbackNative Boolean indicating if the rollback should use native tokens
     */
    function _route(
        address token,
        uint256 amount,
        CellPayload memory payload,
        address rollbackBridge,
        bool rollbackNative
    ) internal {
        Hop memory hop = payload.instructions.hops[0];

        if (hop.action == Action.SwapAndTransfer || hop.action == Action.SwapAndHop) {
            (bool success, address tokenOut, uint256 amountOut) =
                _swap(token, amount, payload.instructions.hops[0].trade);
            if (success) {
                token = tokenOut;
                amount = amountOut;
            } else if (rollbackBridge != address(0) && payload.instructions.rollbackTeleporterFee < amount) {
                _rollback(token, amount, payload, rollbackBridge, rollbackNative);
                return;
            } else {
                revert SwapAndRollbackFailed();
            }
        }

        if (hop.action == Action.SwapAndTransfer) {
            _transfer(token, amount, payload);
        } else if (
            hop.action == Action.Hop || (hop.action == Action.SwapAndHop && payload.instructions.hops.length == 1)
        ) {
            _send(token, amount, payload);
        } else {
            _sendAndCall(token, amount, payload);
        }
    }

    /**
     * @notice Transfers tokens to the specified receiver
     * @dev Handles both ERC20 and native token transfers
     * @param token The address of the token to transfer
     * @param amount The amount of tokens to transfer
     * @param payload The payload containing transfer instructions
     */
    function _transfer(address token, uint256 amount, CellPayload memory payload) internal {
        if (token == address(wrappedNativeToken) && payload.instructions.payableReceiver) {
            wrappedNativeToken.withdraw(amount);
            payable(payload.instructions.receiver).sendValue(amount);
        } else {
            IERC20(token).safeTransfer(payload.instructions.receiver, amount);
        }
    }

    /**
     * @notice Sends tokens to another chain and calls a contract
     * @dev Handles the cross-chain transfer and contract call
     * @param token The address of the token to send
     * @param amount The amount of tokens to send
     * @param payload The payload containing transfer instructions
     */
    function _sendAndCall(address token, uint256 amount, CellPayload memory payload) internal {
        Hop memory hop = payload.instructions.hops[0];
        bool isMultiHop = _isMultiHop(hop);
        SendAndCallInput memory input = SendAndCallInput({
            destinationBlockchainID: hop.bridgePath.destinationBlockchainID,
            destinationTokenTransferrerAddress: hop.bridgePath.bridgeDestinationChain,
            recipientContract: hop.bridgePath.cellDestinationChain,
            recipientPayload: abi.encode(_updatePayload(payload)),
            requiredGasLimit: hop.requiredGasLimit,
            recipientGasLimit: hop.recipientGasLimit,
            multiHopFallback: isMultiHop ? payload.instructions.receiver : address(0),
            fallbackRecipient: payload.instructions.receiver,
            primaryFeeTokenAddress: token,
            primaryFee: hop.bridgePath.teleporterFee,
            secondaryFee: isMultiHop ? hop.bridgePath.secondaryTeleporterFee : 0
        });
        if (hop.bridgePath.sourceBridgeIsNative) {
            wrappedNativeToken.withdraw(amount);
            INativeTokenTransferrer(hop.bridgePath.bridgeSourceChain).sendAndCall{value: amount}(input);
        } else {
            IERC20(token).forceApprove(hop.bridgePath.bridgeSourceChain, amount);
            IERC20TokenTransferrer(hop.bridgePath.bridgeSourceChain).sendAndCall(
                input, amount - hop.bridgePath.teleporterFee
            );
        }
    }

    function _updatePayload(CellPayload memory payload) internal pure returns (CellPayload memory) {
        Hop[] memory hops = new Hop[](payload.instructions.hops.length - 1);
        for (uint256 i = 0; i < payload.instructions.hops.length - 1; i++) {
            hops[i] = payload.instructions.hops[i + 1];
        }
        payload.instructions.hops = hops;
        return payload;
    }

    /**
     * @notice Sends tokens to another chain
     * @dev Handles the cross-chain transfer
     * @param token The address of the token to send
     * @param amount The amount of tokens to send
     * @param payload The payload containing transfer instructions
     */
    function _send(address token, uint256 amount, CellPayload memory payload) internal {
        Hop memory hop = payload.instructions.hops[0];
        bool isMultiHop = _isMultiHop(hop);
        SendTokensInput memory input = SendTokensInput({
            destinationBlockchainID: hop.bridgePath.destinationBlockchainID,
            destinationTokenTransferrerAddress: hop.bridgePath.bridgeDestinationChain,
            recipient: payload.instructions.receiver,
            primaryFeeTokenAddress: token,
            primaryFee: hop.bridgePath.teleporterFee,
            secondaryFee: isMultiHop ? hop.bridgePath.secondaryTeleporterFee : 0,
            requiredGasLimit: hop.requiredGasLimit,
            multiHopFallback: isMultiHop ? payload.instructions.receiver : address(0)
        });
        if (hop.bridgePath.sourceBridgeIsNative) {
            wrappedNativeToken.withdraw(amount);
            INativeTokenTransferrer(hop.bridgePath.bridgeSourceChain).send{value: amount}(input);
        } else {
            IERC20(token).forceApprove(hop.bridgePath.bridgeSourceChain, amount);
            IERC20TokenTransferrer(hop.bridgePath.bridgeSourceChain).send(input, amount - hop.bridgePath.teleporterFee);
        }
    }

    /**
     * @notice Performs a rollback of the transaction
     * @dev This function is called when a swap or transfer fails and needs to be reversed.
     * It sends tokens back to the original chain using the specified rollback bridge.
     * The function handles both native and non-native token rollbacks.
     * @notice The rollback amount sent back is the original amount minus the rollbackTeleporterFee
     * @notice For native token rollbacks, the full amount is sent in the transaction value, but the fee is handled by the bridge
     * @param token The address of the token to rollback
     * @param amount The total amount of tokens to rollback (including fees)
     * @param payload The CellPayload containing rollback instructions and original transaction details
     * @param rollbackBridge The address of the bridge contract to use for the rollback
     * @param rollbackNative A boolean flag indicating whether to rollback native tokens (true) or ERC20 tokens (false)
     */
    function _rollback(
        address token,
        uint256 amount,
        CellPayload memory payload,
        address rollbackBridge,
        bool rollbackNative
    ) internal {
        SendTokensInput memory input = SendTokensInput({
            destinationBlockchainID: payload.sourceBlockchainID,
            destinationTokenTransferrerAddress: payload.rollbackDestination,
            recipient: payload.instructions.receiver,
            primaryFeeTokenAddress: token,
            primaryFee: payload.instructions.rollbackTeleporterFee,
            secondaryFee: 0,
            requiredGasLimit: payload.instructions.rollbackGasLimit,
            multiHopFallback: address(0)
        });
        if (rollbackNative) {
            wrappedNativeToken.withdraw(amount);
            INativeTokenTransferrer(rollbackBridge).send{value: amount}(input);
        } else {
            IERC20(token).forceApprove(rollbackBridge, amount);
            IERC20TokenTransferrer(rollbackBridge).send(input, amount - payload.instructions.rollbackTeleporterFee);
        }
        emit Rollback(payload.instructions.receiver, token, amount - payload.instructions.rollbackTeleporterFee);
    }

    function _isMultiHop(Hop memory hop) internal view returns (bool) {
        try TokenRemote(hop.bridgePath.bridgeSourceChain).tokenHomeBlockchainID() returns (
            bytes32 tokenHomeBlockChainID
        ) {
            return tokenHomeBlockChainID != hop.bridgePath.destinationBlockchainID;
        } catch {
            return false;
        }
    }
}
