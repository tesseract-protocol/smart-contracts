// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ICell, CellPayload, Instructions, Hop, BridgePath, Action} from "./interfaces/ICell.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20TokenTransferrer} from "@ictt/interfaces/IERC20TokenTransferrer.sol";
import {IERC20SendAndCallReceiver} from "@ictt/interfaces/IERC20SendAndCallReceiver.sol";
import {SendAndCallInput, SendTokensInput} from "@ictt/interfaces/ITokenTransferrer.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {INativeTokenTransferrer} from "@ictt/interfaces/INativeTokenTransferrer.sol";
import {INativeSendAndCallReceiver} from "@ictt/interfaces/INativeSendAndCallReceiver.sol";
import {IWrappedNativeToken} from "@ictt/interfaces/IWrappedNativeToken.sol";
import {TokenRemote} from "@ictt/TokenRemote/TokenRemote.sol";
import {IWarpMessenger} from "@avalabs/subnet-evm-contracts@1.2.0/contracts/interfaces/IWarpMessenger.sol";
import {TeleporterRegistryOwnableApp} from "@teleporter/registry/TeleporterRegistryOwnableApp.sol";
import {ITeleporterMessenger} from "@teleporter/ITeleporterMessenger.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
/**
 * @title Cell
 * @dev Abstract contract for facilitating cross-chain token swaps and transfers
 * This contract implements the core functionality for cross-chain operations,
 * including token swaps, transfers, and multi-hop transactions.
 */

abstract contract Cell is ICell, IERC20SendAndCallReceiver, INativeSendAndCallReceiver, TeleporterRegistryOwnableApp {
    using SafeERC20 for IERC20;
    using Address for address payable;

    uint256 public constant BIPS_DIVISOR = 10_000;
    uint256 public constant MAX_BASE_FEE = 500;

    IWrappedNativeToken public immutable wrappedNativeToken;
    bytes32 public immutable blockchainID;

    uint256 public baseFeeBips;
    uint256 public fixedFee;
    address public feeCollector;

    uint256 public tesseractIDNonce;

    struct RouteParams {
        address token;
        uint256 amount;
        CellPayload payload;
        address rollbackBridge;
        bool rollbackNative;
    }

    /**
     * @notice Initializes the Cell contract with wrapped native token configuration
     * @dev Sets up the contract with the wrapped native token address and retrieves the blockchain ID
     * @param wrappedNativeTokenAddress Address of the wrapped native token contract (e.g., WAVAX)
     */
    constructor(
        address owner,
        address wrappedNativeTokenAddress,
        address teleporterRegistry,
        uint256 minTeleporterVersion
    ) TeleporterRegistryOwnableApp(teleporterRegistry, owner, minTeleporterVersion) {
        if (owner == address(0) || wrappedNativeTokenAddress == address(0)) {
            revert InvalidArgument();
        }
        feeCollector = owner;
        wrappedNativeToken = IWrappedNativeToken(wrappedNativeTokenAddress);
        blockchainID = IWarpMessenger(0x0200000000000000000000000000000000000005).getBlockchainID();
    }

    /**
     * @dev Fallback function to receive native tokens
     * @notice Only accepts native tokens from the wrapped native token contract
     */
    receive() external payable virtual {
        if (msg.sender != address(wrappedNativeToken)) revert InvalidSender();
    }

    /**
     * @notice Initiates a cross-chain token operation with support for native and ERC20 tokens
     * @dev Entry point for starting cross-chain operations that:
     *      1. Accepts either native tokens (via msg.value) or ERC20 tokens
     *      2. Wraps native tokens into wrapped native token (e.g., ETH -> WETH)
     *      3. Initiates the cross-chain operation
     * @param token Address of the ERC20 token to be processed
     *              Ignored if native tokens are sent
     * @param amount Amount of ERC20 tokens to process
     *               Ignored if native tokens are sent
     * @param instructions Detailed routing and processing instructions
     */
    function initiate(address token, uint256 amount, Instructions calldata instructions)
        external
        payable
        override
        nonReentrant
    {
        if (amount == 0 && msg.value == 0) {
            revert InvalidAmount();
        }

        if (instructions.hops.length == 0) {
            revert InvalidInstructions();
        }

        (uint256 fixedNativeFee, uint256 baseFee) = calculateFees(instructions, amount);

        if (msg.value < fixedNativeFee) {
            revert InsufficientFeeReceived(fixedNativeFee, msg.value);
        }

        if (msg.value - fixedNativeFee > 0) {
            amount = msg.value - fixedNativeFee;
            wrappedNativeToken.deposit{value: amount}();
            token = address(wrappedNativeToken);
        } else {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }

        if (baseFee > 0) {
            IERC20(token).safeTransfer(feeCollector, baseFee);
            amount -= baseFee;
        }
        if (fixedNativeFee > 0) {
            payable(feeCollector).sendValue(fixedNativeFee);
        }

        tesseractIDNonce++;

        CellPayload memory payload = CellPayload({
            tesseractID: calculateTesseractID(tesseractIDNonce),
            instructions: instructions,
            rollbackDestination: instructions.hops[0].bridgePath.bridgeSourceChain,
            sourceBlockchainID: blockchainID
        });

        _route(
            RouteParams({
                token: token,
                amount: amount,
                payload: payload,
                rollbackBridge: address(0),
                rollbackNative: false
            })
        );

        emit Initiated(
            payload.tesseractID,
            instructions.sourceId,
            tx.origin,
            msg.sender,
            instructions.receiver,
            token,
            amount,
            fixedNativeFee,
            baseFee
        );
    }

    function calculateFees(Instructions memory instructions, uint256 amount)
        public
        view
        returns (uint256 fixedNativeFee, uint256 baseFee)
    {
        if (instructions.hops[0].action != Action.Hop) {
            return (fixedFee, Math.mulDiv(amount, baseFeeBips, BIPS_DIVISOR, Math.Rounding.Up));
        }
    }

    /**
     * @notice Processes incoming cross-chain ERC20 token transfers
     * @dev Handles the receipt and routing of ERC20 tokens from other chains
     * @param sourceBlockchainID Unique identifier of the source blockchain
     * @param originTokenTransferrerAddress Address of the token transferrer contract on source chain
     * @param originSenderAddress Address that initiated the transfer on source chain
     * @param token Address of the received ERC20 token
     * @param amount The amount of tokens received
     * @param payload Encoded CellPayload containing routing and processing instructions
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
     * @notice Processes incoming cross-chain native token transfers
     * @dev Handles receipt of native tokens by:
     *      1. Receiving native tokens via msg.value
     *      2. Immediately wrapping them into ERC20-compliant tokens
     *      3. Processing them using the standard token routing logic
     * This approach ensures consistent handling of both native and ERC20 tokens.
     * @param sourceBlockchainID Unique identifier of the source blockchain
     * @param originTokenTransferrerAddress Address of the token transferrer contract on source chain
     * @param originSenderAddress Address that initiated the transfer on source chain
     * @param payload Encoded CellPayload containing routing and processing instructions
     */
    function receiveTokens(
        bytes32 sourceBlockchainID,
        address originTokenTransferrerAddress,
        address originSenderAddress,
        bytes calldata payload
    ) external payable override nonReentrant {
        emit CellReceivedNativeTokens(sourceBlockchainID, originTokenTransferrerAddress, originSenderAddress, msg.value);
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
        _route(
            RouteParams({
                token: token,
                amount: amount,
                payload: cellPayload,
                rollbackBridge: rollbackBridge,
                rollbackNative: receivedNative
            })
        );
    }

    /**
     * @notice Calculates optimal route for token swap
     * @dev Abstract function that must be implemented by derived contracts
     *      to provide routing logic for token swaps
     * @param amountIn Amount of input tokens to be swapped
     * @param tokenIn Address of the token to swap from
     * @param tokenOut Address of the token to swap to
     * @param extras Additional encoded data required for routing calculation
     * @return trade Encoded trade data containing the optimal route and parameters
     * @return gasEstimate Estimated gas cost to execute the trade
     */
    function route(uint256 amountIn, address tokenIn, address tokenOut, bytes calldata extras)
        external
        view
        virtual
        returns (bytes memory trade, uint256 gasEstimate);

    /**
     * @notice Performs a token swap using provided trade parameters
     * @dev Abstract function that must be implemented by derived contracts.
     * IMPORTANT: Implementation requirements:
     * 1. Must use try/catch blocks for comprehensive error handling
     * 2. Must never revert; all errors should be returned via success parameter
     * 3. Must handle all exceptions gracefully
     *
     * Error Handling:
     * - On success: return (true, actual_token_address, actual_amount)
     * - On failure: return (false, address(0), 0)
     *
     * @param token Address of input token to be swapped
     * @param amount Number of input tokens to swap
     * @param tradePayload Encoded swap parameters and routing information
     * @return success True if swap succeeded, false otherwise
     * @return tokenOut Address of output token (address(0) if failed)
     * @return amountOut Amount of output tokens received (0 if failed)
     */
    function _swap(address token, uint256 amount, bytes memory tradePayload)
        internal
        virtual
        returns (bool success, address tokenOut, uint256 amountOut);

    /**
     * @notice Routes the tokens based on the provided payload
     * @dev Handles swapping, transferring, and sending tokens across chains
     */
    function _route(RouteParams memory routeParams) internal {
        Hop memory hop = routeParams.payload.instructions.hops[0];

        address tokenOut = routeParams.token;
        uint256 amountOut = routeParams.amount;

        if (hop.action == Action.SwapAndTransfer || hop.action == Action.SwapAndHop) {
            bool success;
            (success, tokenOut, amountOut) = _swap(routeParams.token, routeParams.amount, hop.trade);
            if (
                !success && routeParams.rollbackBridge != address(0)
                    && routeParams.payload.instructions.rollbackTeleporterFee < routeParams.amount
            ) {
                _rollback(
                    routeParams.token,
                    routeParams.amount,
                    routeParams.payload,
                    routeParams.rollbackBridge,
                    routeParams.rollbackNative
                );
                return;
            } else if (!success) {
                revert SwapAndRollbackFailed();
            }
        }

        if (
            (hop.action == Action.Hop || hop.action == Action.HopAndCall) && hop.bridgePath.sourceBridgeIsNative
                && tokenOut != address(wrappedNativeToken)
        ) {
            revert InvalidInstructions();
        }

        bytes32 messageID;

        if (hop.action == Action.SwapAndTransfer) {
            _transfer(tokenOut, amountOut, routeParams.payload);
        } else if (
            hop.action == Action.Hop
                || (hop.action == Action.SwapAndHop && routeParams.payload.instructions.hops.length == 1)
        ) {
            messageID = _send(tokenOut, amountOut, routeParams.payload);
        } else {
            messageID = _sendAndCall(tokenOut, amountOut, routeParams.payload);
        }

        emit CellRouted(
            routeParams.payload.tesseractID,
            messageID,
            hop.action,
            hop.action == Action.SwapAndTransfer ? address(0) : hop.bridgePath.bridgeSourceChain,
            hop.action == Action.SwapAndTransfer ? bytes32(0) : hop.bridgePath.destinationBlockchainID,
            hop.action == Action.HopAndCall ? hop.bridgePath.cellDestinationChain : address(0),
            hop.action == Action.SwapAndTransfer ? address(0) : hop.bridgePath.bridgeDestinationChain,
            routeParams.token,
            routeParams.amount,
            tokenOut,
            amountOut
        );
    }

    /**
     * @notice Transfers tokens to final destination address
     * @dev Handles both ERC20 and native token transfers:
     *      - For native tokens: unwraps and sends directly
     *      - For ERC20: uses safe transfer
     * @param token Address of token to transfer
     * @param amount Amount of tokens to transfer
     * @param payload CellPayload containing transfer instructions
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
     * @notice Sends tokens to another blockchain with contract call
     * @dev Initiates cross-chain token transfer with contract interaction
     * @param token Address of token to send
     * @param amount Amount of tokens to send
     * @param payload CellPayload containing bridge and contract call instructions
     */
    function _sendAndCall(address token, uint256 amount, CellPayload memory payload)
        internal
        returns (bytes32 messageID)
    {
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

        messageID = ITeleporterMessenger(teleporterRegistry.getLatestTeleporter()).getNextMessageID(
            hop.bridgePath.destinationBlockchainID
        );

        if (hop.bridgePath.sourceBridgeIsNative) {
            wrappedNativeToken.withdraw(amount - hop.bridgePath.teleporterFee);
            IERC20(token).forceApprove(hop.bridgePath.bridgeSourceChain, hop.bridgePath.teleporterFee);
            INativeTokenTransferrer(hop.bridgePath.bridgeSourceChain).sendAndCall{
                value: amount - hop.bridgePath.teleporterFee
            }(input);
        } else {
            IERC20(token).forceApprove(hop.bridgePath.bridgeSourceChain, amount);
            IERC20TokenTransferrer(hop.bridgePath.bridgeSourceChain).sendAndCall(
                input, amount - hop.bridgePath.teleporterFee
            );
        }
    }

    /**
     * @notice Updates payload for next hop
     * @dev Removes current hop from instructions and prepares payload for next chain
     * @param payload Current CellPayload to update
     * @return Updated CellPayload with next hop instructions
     */
    function _updatePayload(CellPayload memory payload) internal pure returns (CellPayload memory) {
        Hop[] memory hops = new Hop[](payload.instructions.hops.length - 1);
        for (uint256 i = 0; i < payload.instructions.hops.length - 1; i++) {
            hops[i] = payload.instructions.hops[i + 1];
        }
        payload.instructions.hops = hops;
        return payload;
    }

    /**
     * @notice Sends tokens to another blockchain
     * @dev Initiates cross-chain token transfer without contract call
     * @param token Address of token to send
     * @param amount Amount of tokens to send
     * @param payload CellPayload containing bridge instructions
     */
    function _send(address token, uint256 amount, CellPayload memory payload) internal returns (bytes32 messageID) {
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

        messageID = ITeleporterMessenger(teleporterRegistry.getLatestTeleporter()).getNextMessageID(
            hop.bridgePath.destinationBlockchainID
        );

        if (hop.bridgePath.sourceBridgeIsNative) {
            wrappedNativeToken.withdraw(amount - hop.bridgePath.teleporterFee);
            IERC20(token).forceApprove(hop.bridgePath.bridgeSourceChain, hop.bridgePath.teleporterFee);
            INativeTokenTransferrer(hop.bridgePath.bridgeSourceChain).send{value: amount - hop.bridgePath.teleporterFee}(
                input
            );
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
            recipient: payload.instructions.rollbackReceiver,
            primaryFeeTokenAddress: token,
            primaryFee: payload.instructions.rollbackTeleporterFee,
            secondaryFee: 0,
            requiredGasLimit: payload.instructions.rollbackGasLimit,
            multiHopFallback: address(0)
        });

        bytes32 messageID =
            ITeleporterMessenger(teleporterRegistry.getLatestTeleporter()).getNextMessageID(payload.sourceBlockchainID);

        if (rollbackNative) {
            wrappedNativeToken.withdraw(amount - payload.instructions.rollbackTeleporterFee);
            IERC20(token).forceApprove(rollbackBridge, payload.instructions.rollbackTeleporterFee);
            INativeTokenTransferrer(rollbackBridge).send{value: amount - payload.instructions.rollbackTeleporterFee}(
                input
            );
        } else {
            IERC20(token).forceApprove(rollbackBridge, amount);
            IERC20TokenTransferrer(rollbackBridge).send(input, amount - payload.instructions.rollbackTeleporterFee);
        }
        emit CellRollback(
            payload.tesseractID,
            messageID,
            rollbackBridge,
            payload.instructions.rollbackReceiver,
            payload.sourceBlockchainID,
            payload.rollbackDestination,
            token,
            amount,
            amount - payload.instructions.rollbackTeleporterFee
        );
    }

    /**
     * @notice Checks if current hop is part of a multi-hop transaction
     * @dev Determines if tokens need to traverse multiple chains
     * @param hop Current hop information
     * @return True if this is part of multi-hop transaction, false otherwise
     */
    function _isMultiHop(Hop memory hop) internal view returns (bool) {
        try TokenRemote(hop.bridgePath.bridgeSourceChain).getTokenHomeBlockchainID() returns (
            bytes32 tokenHomeBlockChainID
        ) {
            return tokenHomeBlockChainID != hop.bridgePath.destinationBlockchainID;
        } catch {
            return false;
        }
    }

    function calculateTesseractID(uint256 nonce) public view returns (bytes32) {
        return keccak256(abi.encode(address(this), blockchainID, nonce));
    }

    /**
     * @dev Receives Teleporter messages and handles accordingly.
     * This function should be overridden by contracts that inherit from this contract.
     */
    function _receiveTeleporterMessage(bytes32 sourceBlockchainID, address originSenderAddress, bytes memory message)
        internal
        virtual
        override
    {}

    /**
     * @notice Updates the fee collector address
     * @param newFeeCollector The address of the new fee collector
     */
    function updateFeeCollector(address newFeeCollector) external onlyOwner {
        if (newFeeCollector == address(0)) {
            revert InvalidFeeCollectorUpdate();
        }
        feeCollector = newFeeCollector;
        emit FeeCollectorUpdated(newFeeCollector);
    }

    /**
     * @notice Updates the base fee in basis points (bips)
     * @param newBaseFeeBips The new base fee in basis points
     */
    function updateBaseFeeBips(uint256 newBaseFeeBips) external onlyOwner {
        if (newBaseFeeBips > MAX_BASE_FEE) {
            revert InvalidBaseFeeUpdate();
        }
        baseFeeBips = newBaseFeeBips;
        emit BaseFeeUpdated(newBaseFeeBips);
    }

    /**
     * @notice Updates the fixed fee amount
     * @param newFixedFee The new fixed fee amount
     */
    function updateFixedFee(uint256 newFixedFee) external onlyOwner {
        fixedFee = newFixedFee;
        emit FixedFeeUpdated(newFixedFee);
    }

    /**
     * @notice Emergency function to recover accidentally sent ERC20 tokens
     * @dev Allows contract owner to retrieve tokens that are stuck in the contract
     *      This is a safety mechanism only - under normal operation, the contract
     *      should not hold any token balances outside of active operations
     *
     * Security Considerations:
     * - Only callable by contract owner
     * - Cannot be called during active operations
     * - Only be used for genuinely stuck tokens
     *
     * @param token Address of the ERC20 token to recover
     * @param amount Amount of tokens to recover (must be > 0)
     */
    function recoverERC20(address token, uint256 amount) external onlyOwner {
        if (amount == 0) {
            revert InvalidAmount();
        }
        IERC20(token).safeTransfer(msg.sender, amount);
        emit Recovered(token, amount);
    }

    /**
     * @notice Emergency function to recover accidentally sent native tokens
     * @dev Allows contract owner to retrieve native tokens that are stuck in the contract
     *      This is a safety mechanism only - under normal operation, the contract
     *      should not hold native token balance outside of active operations
     *
     * Security Considerations:
     * - Only callable by contract owner
     * - Cannot be called during active operations
     * - Only be used for genuinely stuck native tokens
     *
     * @param amount Amount of native tokens to recover (must be > 0)
     */
    function recoverNative(uint256 amount) external onlyOwner {
        if (amount == 0) {
            revert InvalidAmount();
        }
        payable(msg.sender).sendValue(amount);
        emit Recovered(address(0), amount);
    }
}
