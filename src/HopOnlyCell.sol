// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./Cell.sol";

contract HopOnlyCell is Cell {
    function route(uint256 amountIn, address tokenIn, address tokenOut, bytes calldata extras)
        external
        view
        override
        returns (bytes memory trade, uint256 gasEstimate)
    {}

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
