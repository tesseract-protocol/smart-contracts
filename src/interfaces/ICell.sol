// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/**
 * @dev Payload structure for Cell operations
 * @param instructions Detailed instructions for the operation
 * @param hop Current hop count in the operation sequence
 */
struct CellPayload {
    Instructions instructions;
    bytes32 sourceBlockchainID;
    address rollbackDestination;
}

/**
 * @dev Instructions for a cross-chain swap operation
 * @param receiver Address that will receive the final tokens
 * @param rollbackTeleporterFee Concrete amount of the input token (tokenIn) to be used as fee for rollback operation via Teleporter
 * @param hops Array of Hop structures defining the swap path
 */
struct Instructions {
    address receiver;
    bool payableReceiver;
    bytes32 sourceBlockchainId;
    uint256 rollbackTeleporterFee;
    uint256 rollbackGasLimit;
    Hop[] hops;
}

/**
 * @dev Defines a single hop in a cross-chain swap operation
 * @param action Type of action to be performed in this hop
 * @param gasLimit Gas limit for this hop's operation
 * @param trade Encoded trade data for swap operations
 * @param bridgePath Defines the path for bridging tokens between chains
 */
struct Hop {
    Action action;
    uint256 requiredGasLimit;
    uint256 recipientGasLimit;
    bytes trade;
    BridgePath bridgePath;
}

/**
 * @dev Defines the path for bridging tokens between chains
 * @param multihop Indicates if multihop should be used in this hop. If true, secondaryTeleporterFee might be set.
 * @param bridgeSourceChain Address of the bridge on the source chain
 * @param bridgeDestinationChain Address of the bridge on the destination chain
 * @param cellDestinationChain Address of the Cell contract on the destination chain
 * @param destinationBlockchainID Identifier of the destination blockchain
 * @param teleporterFee Concrete amount of tokens to be used as fee for the Teleporter service.
 *        This is in tokenIn if no swap occurred in this hop, or in tokenOut if a swap did occur.
 * @param secondaryTeleporterFee Secondary fee for the Teleporter service. This might be set if multihop is true.
 */
struct BridgePath {
    address bridgeSourceChain;
    bool sourceBridgeIsNative;
    address bridgeDestinationChain;
    bool destinationBridgeIsNative;
    address cellDestinationChain;
    bytes32 destinationBlockchainID;
    uint256 teleporterFee;
    uint256 secondaryTeleporterFee;
}

/**
 * @dev Enumeration of possible actions in a hop
 * Hop: Simple token transfer between chains
 * HopAndCall: Token transfer followed by a contract call on the destination chain.
 * SwapAndHop: Perform a swap, then transfer to another chain
 * SwapAndTransfer: Perform a swap and transfer tokens to the final receiver
 */
enum Action {
    Hop,
    HopAndCall,
    SwapAndHop,
    SwapAndTransfer
}
/**
 * @title ICell Interface
 * @dev Interface for the Cell contract, defining structures and functions for cross-chain token swaps and transfers
 */

interface ICell {
    /**
     * @dev Emitted when tokens are received by the Cell contract
     * @param sourceBlockchainID Identifier of the source blockchain
     * @param sourceBridge Address of the bridge on the source chain
     * @param originSender Address of the original sender
     * @param token Address of the received token
     * @param amount Amount of tokens received
     */
    event CellReceivedTokens(
        bytes32 indexed sourceBlockchainID,
        address indexed sourceBridge,
        address indexed originSender,
        address token,
        uint256 amount
    );

    event CellReceivedNativeTokens(
        bytes32 indexed sourceBlockchainID, address indexed sourceBridge, address indexed originSender
    );

    /**
     * @dev Emitted when a cross-chain swap/bridge is initiated
     * @param sender Address initiating
     * @param token Address of the input token
     * @param amount Amount of input tokens
     */
    event Initiated(address indexed sender, address indexed token, uint256 amount);

    /**
     * @dev Emitted when a rollback operation is performed
     * @param receiver Address receiving the rolled-back tokens
     * @param token Address of the token being rolled back
     * @param amount Amount of tokens being rolled back
     */
    event Rollback(address indexed receiver, address indexed token, uint256 amount);

    error SwapFailed();
    error RollbackFailedInvalidFee();
    error InvalidAmount();

    error InvalidSender();

    /**
     * @notice Initiates a cross-chain swap operation
     * @dev This function starts the process of a cross-chain token swap.
     * It should transfer the specified tokens from the caller to the contract,
     * then initiate the swap process according to the provided instructions.
     * @param token Address of the token to be swapped
     * @param amount Amount of tokens to be swapped
     * @param instructions Detailed instructions for the swap operation
     */
    function initiate(address token, uint256 amount, Instructions calldata instructions) external;
}
