// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Cell} from "./Cell.sol";
import {CellPayload} from "./interfaces/ICell.sol";

/**
 * @title HopOnlyCell
 * @notice Cell implementation for cross-chain token transfers without swaps
 * @dev A minimal implementation of the Cell contract that:
 *      1. Supports direct token transfers across chains
 *      2. Disables swap functionality
 *      3. Maintains original token and amount throughout the transfer
 *
 * Use Cases:
 * - Direct token bridging across chains
 * - Multi-hop token transfers without exchanges
 * - Simplified cross-chain token movements
 *
 */
contract HopOnlyCell is Cell {
    /**
     * @notice Creates new HopOnlyCell instance
     * @dev Initializes the contract with wrapped native token support
     * @param wrappedNativeToken Address of the wrapped native token contract
     */
    constructor(address wrappedNativeToken) Cell(wrappedNativeToken) {}

    /**
     * @notice Required interface implementation for routing (non-functional)
     * @dev Implements the required Cell interface function without actual routing logic
     *      Always returns empty values since this contract doesn't perform swaps
     *
     * @return trade Empty bytes array (no trade data needed)
     * @return gasEstimate Zero (no gas estimation needed)
     */
    function route(uint256, address, address, bytes calldata)
        external
        pure
        override
        returns (bytes memory trade, uint256 gasEstimate)
    {
        // Implementation is empty as no routing is needed for simple hops
        return ("", 0);
    }

    /**
     * @notice Pass-through implementation of swap functionality
     * @dev Overrides Cell's _swap function with a no-op implementation that:
     *      1. Returns the input token and amount unchanged
     *      2. Always indicates success
     *      3. Performs no actual token exchange
     *
     * This implementation ensures that tokens remain unchanged during cross-chain transfers.
     *
     * @return success Always true (operation cannot fail)
     * @return tokenOut Same as input token address
     * @return amountOut Same as input amount
     */
    function _swap(address token, uint256 amount, bytes memory)
        internal
        pure
        override
        returns (bool success, address tokenOut, uint256 amountOut)
    {
        success = true;
        tokenOut = token;
        amountOut = amount;
    }
}
