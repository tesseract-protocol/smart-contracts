// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./Cell.sol";

contract HopOnlyCell is Cell {
    constructor(address teleporterRegistryAddress, address primaryFeeTokenAddress)
        Cell(teleporterRegistryAddress, primaryFeeTokenAddress)
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
