// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./Cell.sol";
import "./interfaces/IYakRouter.sol";

contract YakSwapCell is Cell {
    IYakRouter public immutable router;

    constructor(address teleporterRegistryAddress, address routerAddress, address primaryFeeTokenAddress)
        Cell(teleporterRegistryAddress, primaryFeeTokenAddress)
    {
        router = IYakRouter(routerAddress);
    }

    function _swap(address token, uint256 amount, CellPayload memory payload)
        internal
        override
        returns (bool success, address tokenOut, uint256 amountOut)
    {
        Trade memory trade = abi.decode(payload.instructions.hops[payload.hop].trade, (Trade));
        tokenOut = trade.path.length > 0 ? trade.path[trade.path.length - 1] : address(0);
        if (tokenOut == address(0)) {
            return (false, address(0), 0);
        }
        uint256 balanceBefore = IERC20(tokenOut).balanceOf(address(this));
        IERC20(token).approve(address(router), amount);
        try IYakRouter(router).swapNoSplit(trade, address(this), 0) {
            success = true;
            amountOut = IERC20(tokenOut).balanceOf(address(this)) - balanceBefore;
        } catch {
            IERC20(token).approve(address(router), 0);
        }
    }
}
