// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Cell} from "./Cell.sol";
import {CellPayload} from "./interfaces/ICell.sol";
import {IYakRouter, FormattedOffer, Trade} from "./interfaces/IYakRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title YakSwapCell
 * @dev A concrete implementation of the Cell contract for cross-chain swaps using the YakRouter
 */
contract YakSwapCell is Cell {
    /**
     * @dev Additional parameters for the YakRouter swap
     * @param maxSteps Maximum number of steps in the swap path
     * @param gasPrice Gas price to be used for gas estimation
     * @param slippageBips Slippage tolerance in basis points (1 bip = 0.01%)
     */
    struct Extras {
        uint256 maxSteps;
        uint256 gasPrice;
        uint256 slippageBips;
    }

    uint256 public constant BIPS_DIVISOR = 10_000;

    /**
     * @dev The YakRouter instance used for finding swap paths and executing swaps
     */
    IYakRouter public immutable router;

    /**
     * @dev Constructs the YakSwapCell with a specified YakRouter
     * @param routerAddress The address of the YakRouter contract
     */
    constructor(address routerAddress) {
        router = IYakRouter(routerAddress);
    }

    /**
     * @notice Finds the best swap path for given tokens and amount
     * @dev This function is called externally to determine the optimal swap path
     * @param amountIn The amount of input tokens to swap
     * @param tokenIn The address of the input token
     * @param tokenOut The address of the desired output token
     * @param data Encoded Extras struct containing additional swap parameters
     * @return trade Encoded Trade struct containing the optimal swap path
     * @return gasEstimate Estimated gas cost for the swap
     */
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
                amountOut: (offer.amounts[offer.amounts.length - 1] * (BIPS_DIVISOR - extras.slippageBips)) / BIPS_DIVISOR,
                path: offer.path,
                adapters: offer.adapters
            })
        );
        gasEstimate = offer.gasEstimate;
    }

    /**
     * @notice Executes a token swap using the YakRouter
     * @dev This internal function is called as part of the cross-chain swap process
     * @param token The address of the input token
     * @param amount The amount of input tokens to swap
     * @param payload The CellPayload containing swap instructions
     * @return success Boolean indicating if the swap was successful
     * @return tokenOut The address of the output token
     * @return amountOut The amount of output tokens received
     */
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
