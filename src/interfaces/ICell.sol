// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/**
 * @notice Core payload structure for all Cell cross-chain operations
 * @dev Encapsulates all necessary information for executing and rolling back cross-chain operations
 * @param instructions Detailed instructions for executing the cross-chain operation
 * @param sourceBlockchainID Unique identifier of the originating blockchain
 * @param rollbackDestination Bridge on the source chain to receive tokens in case of operation failure
 */
struct CellPayload {
    Instructions instructions;
    bytes32 sourceBlockchainID;
    address rollbackDestination;
}

/**
 * @notice Detailed instructions for cross-chain operations
 * @dev Defines the complete path and parameters for token movement across chains
 * @param receiver Address that will receive the final tokens
 * @param payableReceiver Boolean indicating if receiver can/should receive native tokens
 * @param rollbackTeleporterFee Amount of input token for rollback operation fees
 * @param rollbackGasLimit Gas limit for rollback operations
 * @param hops Ordered array of Hop structures defining the complete operation path
 */
struct Instructions {
    address receiver;
    bool payableReceiver;
    uint256 rollbackTeleporterFee;
    uint256 rollbackGasLimit;
    Hop[] hops;
}

/**
 * @notice Represents a single step in a cross-chain operation
 * @dev Each hop can involve a swap, transfer, or both, between chains
 * @param action Enum defining the type of operation for this hop
 * @param requiredGasLimit Gas limit for the whole operation (bridge + recipientGasLimit)
 * @param recipientGasLimit Gas limit for any recipient contract calls
 * @param trade Encoded trade data (interpretation depends on action type)
 * @param bridgePath Detailed path information for cross-chain token movement
 */
struct Hop {
    Action action;
    uint256 requiredGasLimit;
    uint256 recipientGasLimit;
    bytes trade;
    BridgePath bridgePath;
}

/**
 * @notice Defines the complete path for cross-chain token bridging
 * @dev Contains all necessary information for token movement between chains
 *
 * Fee Handling:
 * - Primary fee is in input token if no swap occurred, output token if swapped
 * - Secondary fee used for multi-hop scenarios
 *
 * @param bridgeSourceChain Address of bridge contract on source chain
 * @param sourceBridgeIsNative True if bridge handles native tokens
 * @param bridgeDestinationChain Address of bridge contract on destination chain
 * @param cellDestinationChain Address of Cell contract on destination chain
 * @param destinationBlockchainID Unique identifier of destination blockchain
 * @param teleporterFee Primary fee for Teleporter service
 * @param secondaryTeleporterFee Additional fee for multi-hop operations
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
 * @notice Available actions for each hop in a cross-chain operation
 * @dev Defines all possible operations that can be performed in a single hop
 *
 * Actions:
 * @param Hop Simple token transfer between chains
 *        - No swap involved
 *        - Direct bridge transfer
 *
 * @param HopAndCall Token transfer with destination contract call
 *        - Includes contract interaction
 *        - Requires recipient gas limit
 *
 * @param SwapAndHop Token swap followed by chain transfer
 *        - Performs swap first
 *        - Then bridges to destination
 *
 * @param SwapAndTransfer Token swap with final transfer
 *        - Last hop in path
 *        - Delivers to final receiver
 */
enum Action {
    Hop,
    HopAndCall,
    SwapAndHop,
    SwapAndTransfer
}

/**
 * @title ICell Interface
 * @notice Core interface for Cell protocol's cross-chain token operations
 * @dev Defines the essential contract interface for implementing cross-chain token swaps and transfers
 *
 * Key Features:
 * - Cross-chain token transfers
 * - Token swaps across chains
 * - Multi-hop operations
 * - Rollback convenience mechanism
 */
interface ICell {
    /**
     * @notice Emitted when Cell contract receives tokens from another chain
     * @dev Logs all cross-chain token receipts for tracking and verification
     * @param sourceBlockchainID Origin chain identifier (indexed)
     * @param sourceBridge Bridge contract that sent the tokens (indexed)
     * @param originSender Original sender address on source chain (indexed)
     * @param token Address of received token
     * @param amount Number of tokens received
     * @custom:tracking Essential for cross-chain transaction tracking
     */
    event CellReceivedTokens(
        bytes32 indexed sourceBlockchainID,
        address indexed sourceBridge,
        address indexed originSender,
        address token,
        uint256 amount
    );

    /**
     * @notice Emitted when Cell contract receives native tokens
     * @dev Logs cross-chain native token receipts
     * @param sourceBlockchainID Origin chain identifier (indexed)
     * @param sourceBridge Bridge contract that sent tokens (indexed)
     * @param originSender Original sender address (indexed)
     * @custom:tracking Used for native token transfer tracking
     */
    event CellReceivedNativeTokens(
        bytes32 indexed sourceBlockchainID, address indexed sourceBridge, address indexed originSender
    );

    /**
     * @notice Emitted when a new cross-chain operation is initiated
     * @dev Logs the start of a new operation for tracking
     * @param sender Address initiating the operation (indexed)
     * @param token Address of input token (indexed)
     * @param amount Number of tokens being processed
     */
    event Initiated(address indexed sender, address indexed token, uint256 amount, bytes instructions);

    /**
     * @notice Emitted when tokens are returned due to operation failure
     * @dev Logs rollback operations for tracking failed transactions
     * @param receiver Address receiving returned tokens (indexed)
     * @param token Address of returned token (indexed)
     * @param amount Amount of tokens returned
     */
    event Rollback(address indexed receiver, address indexed token, uint256 amount);

    /**
     * @notice Event emitted when tokens are recovered from the contract
     * @dev This event serves multiple purposes:
     *      1. Tracks emergency token recoveries
     *      2. Provides transparency for contract token movements
     *      3. Helps audit unexpected token accumulation
     *
     * Token Address Interpretation:
     * - address(0) indicates native token recovery
     * - non-zero address indicates ERC20 token recovery
     *
     * @param token Address of recovered token (address(0) for native tokens)
     * @param amount Amount of tokens recovered
     */
    event Recovered(address indexed token, uint256 amount);

    /**
     * @notice Custom errors for Cell operations
     * @dev Defined errors provide specific failure information
     *
     * error InvalidSender - Thrown when unauthorized address attempts operation
     * error SwapAndRollbackFailed - Critical error when both swap and rollback fail
     * error RollbackFailedInvalidFee - Thrown when rollback fails due to insufficient fee
     * error InvalidAmount - Thrown when operation amount is zero or invalid
     * error InvalidInstructions - Thrown when instructions are invalid
     * error InvalidArgument - Thrown when constructor receives invalid arguments
     */
    error InvalidSender();
    error SwapAndRollbackFailed();
    error RollbackFailedInvalidFee();
    error InvalidAmount();
    error InvalidInstructions();
    error InvalidArgument();

    /**
     * @notice Initiates a cross-chain token operation with native or ERC20 token support
     * @dev Primary entry point for all Cell cross-chain operations
     *
     * Operation Flow:
     * 1. Accepts ERC20 tokens (via amount) or native tokens (via msg.value)
     * 2. Native tokens are automatically wrapped
     * 3. Validates parameters and instructions
     * 4. Initiates cross-chain operation
     * 5. Handles failures via rollback mechanism
     *
     * @param token Address of ERC20 token (ignored when sending native tokens)
     * @param amount Amount of ERC20 tokens (ignored when sending native tokens)
     * @param instructions Detailed path and operation instructions for the cross-chain operation
     *
     * @custom:example
     * // For ERC20 tokens:
     * cell.initiate(tokenAddress, 1000, instructions);
     *
     * // For native tokens:
     * cell.initiate{value: 1 ether}(address(0), 0, instructions);
     */
    function initiate(address token, uint256 amount, Instructions calldata instructions) external payable;
}
