// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./Cell.sol";

contract HopOnlyCell is Cell {
    constructor(address teleporterRegistryAddress, address primaryFeeTokenAddress)
        Cell(teleporterRegistryAddress, primaryFeeTokenAddress)
    {}

    function _swap(address token, uint256 amount, CellPayload memory)
        internal
        override
        returns (address tokenOut, uint256 amountOut)
    {
        tokenOut = token;
        amountOut = amount;
    }
}
