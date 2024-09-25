// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/**
 * @dev Payload structure for Cell operations
 * @param instructions Detailed instructions for the cross-chain operation
 * @param sourceBlockchainID Identifier of the blockchain where the operation originated
 * @param rollbackDestination Address to send tokens to in case of a rollback
 */
struct CellPayload {
    Instructions instructions;
    bytes32 sourceBlockchainID;
    address rollbackDestination;
}

/**
 * @dev Instructions for a cross-chain swap operation
 * @param receiver Address that will receive the final tokens
 * @param payableReceiver Boolean indicating if the receiver can accept native tokens
 * @param rollbackTeleporterFee Amount of the input token (tokenIn) to be used as fee for rollback operation via Teleporter
 * @param hops Array of Hop structures defining the swap path
 */
struct Instructions {
    address receiver;
    bool payableReceiver;
    uint256 rollbackTeleporterFee;
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
    uint256 gasLimit;
    bytes trade;
    BridgePath bridgePath;
}

/**
 * @dev Defines the path for bridging tokens between chains
 * @param bridgeSourceChain Address of the bridge on the source chain
 * @param sourceBridgeIsNative Boolean indicating if the source bridge handles native tokens
 * @param bridgeDestinationChain Address of the bridge on the destination chain
 * @param cellDestinationChain Address of the Cell contract on the destination chain
 * @param destinationBlockchainID Identifier of the destination blockchain
 * @param teleporterFee Amount of tokens to be used as fee for the Teleporter service.
 *        This is in tokenIn if no swap occurred in this hop, or in tokenOut if a swap did occur.
 * @param secondaryTeleporterFee Secondary fee for the Teleporter service. This might be set in multihop scenarios.
 */
struct BridgePath {
    address bridgeSourceChain;
    bool sourceBridgeIsNative;
    address bridgeDestinationChain;
    address cellDestinationChain;
    bytes32 destinationBlockchainID;
    uint256 teleporterFee;
    uint256 secondaryTeleporterFee;
}

/**
 * @dev Enumeration of possible actions in a hop
 * @param Hop Simple token transfer between chains
 * @param HopAndCall Token transfer followed by a contract call on the destination chain
 * @param SwapAndHop Perform a swap, then transfer to another chain
 * @param SwapAndTransfer Perform a swap and transfer tokens to the final receiver
 */
enum Action {
    Hop,
    HopAndCall,
    SwapAndHop,
    SwapAndTransfer
}

/**
 * @title ICell Interface
 * @dev Interface for the Cell contract, defining events, errors, and functions for cross-chain token swaps and transfers
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

    /**
     * @dev Emitted when native tokens are received by the Cell contract
     * @param sourceBlockchainID Identifier of the source blockchain
     * @param sourceBridge Address of the bridge on the source chain
     * @param originSender Address of the original sender
     */
    event CellReceivedNativeTokens(
        bytes32 indexed sourceBlockchainID, address indexed sourceBridge, address indexed originSender
    );

    /**
     * @dev Emitted when a cross-chain swap is initiated
     * @param sender Address initiating the swap
     * @param tokenIn Address of the input token
     * @param amountIn Amount of input tokens
     */
    event InitiatedSwap(address indexed sender, address indexed tokenIn, uint256 amountIn);

    /**
     * @dev Emitted when a rollback operation is performed
     * @param receiver Address receiving the rolled-back tokens
     * @param token Address of the token being rolled back
     * @param amount Amount of tokens being rolled back
     */
    event Rollback(address indexed receiver, address indexed token, uint256 indexed amount);

    /**
     * @dev Error thrown when an invalid sender tries to interact with the contract
     */
    error InvalidSender();

    /**
     * @dev Error thrown when both the swap operation and the subsequent rollback attempt fail
     * This error indicates a critical failure in the system where not only did the initial
     * swap fail, but the safety mechanism (rollback) also failed to execute properly
     */
    error SwapAndRollbackFailed();

    /**
     * @notice Initiates a cross-chain swap operation
     * @dev This function starts the process of a cross-chain token swap.
     * It transfers the specified tokens from the caller to the contract,
     * then initiates the swap process according to the provided instructions.
     * If the swap fails, a rollback will be attempted. If both the swap and rollback fail,
     * the SwapAndRollbackFailed error will be thrown.
     * @param token Address of the token to be swapped
     * @param amount Amount of tokens to be swapped
     * @param instructions Detailed instructions for the swap operation
     */
    function crossChainSwap(address token, uint256 amount, Instructions calldata instructions) external payable;
}
