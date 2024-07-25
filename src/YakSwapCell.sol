// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./Cell.sol";
import "./interfaces/IYakRouter.sol";

contract YakSwapCell is Cell {
    struct Extras {
        uint256 maxSteps;
        uint256 gasPrice;
        uint256 slippageBips;
    }

    IYakRouter public immutable router;

    constructor(address teleporterRegistryAddress, address routerAddress, address primaryFeeTokenAddress)
        Cell(teleporterRegistryAddress, primaryFeeTokenAddress)
    {
        router = IYakRouter(routerAddress);
    }

    function route(uint256 amountIn, address tokenIn, address tokenOut, bytes calldata data)
        external
        view
        override
        returns (bytes memory trade, uint256 gasEstimate)
    {
        Extras memory extras = abi.decode(data, (Extras));
        FormattedOffer memory offer =
            router.findBestPathWithGas(amountIn, tokenIn, tokenOut, extras.maxSteps, extras.gasPrice);
        trade = abi.encode(
            Trade({
                amountIn: offer.amounts[0],
                amountOut: (offer.amounts[offer.amounts.length - 1] * (10_000 - extras.slippageBips)) / 10_000,
                path: offer.path,
                adapters: offer.adapters
            })
        );
        gasEstimate = offer.gasEstimate;
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
