// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Cell} from "./Cell.sol";
import {CellPayload} from "./interfaces/ICell.sol";

/**
 * @title HopOnlyCell
 * @dev A simplified implementation of the Cell contract that only supports token transfers (hops) without swaps
 * This contract is useful for scenarios where tokens need to be transferred across chains without any exchange
 */
contract HopOnlyCell is Cell {
    constructor(address wrappedNativeToken) Cell(wrappedNativeToken) {}

    /**
     * @notice Placeholder function for routing logic
     * @dev This function is required by the Cell interface but is not used in HopOnlyCell
     * It returns empty values as no actual routing is performed
     * @return trade An empty bytes array as no trade is performed
     * @return gasEstimate Always returns 0 as no gas estimation is needed
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
     * @notice Simulates a swap operation by returning the input token and amount
     * @dev This function overrides the _swap function in the Cell contract
     * Instead of performing a swap, it simply returns the input token and amount,
     * effectively performing a transfer without exchange
     * @param token The address of the input token
     * @param amount The amount of input tokens
     * @return success Always returns true as the operation always succeeds
     * @return tokenOut Returns the input token address
     * @return amountOut Returns the input amount
     */
    function _swap(address token, uint256 amount, CellPayload memory)
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
