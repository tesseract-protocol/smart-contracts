// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Cell} from "./Cell.sol";
import {CellPayload} from "./interfaces/ICell.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IYakRouter, FormattedOffer, Trade} from "./interfaces/IYakRouter.sol";

/**
 * @title YakSwapCell
 * @notice Implementation of Cell contract for cross-chain swaps using YakRouter
 * @dev Concrete implementation of the Cell contract that:
 *      1. Uses YakRouter for finding optimal swap paths
 *      2. Executes swaps through YakRouter's aggregation protocol
 *      3. Handles slippage control and gas estimation
 */
contract YakSwapCell is Cell {
    using SafeERC20 for IERC20;

    /**
     * @notice Configuration parameters for YakRouter swaps
     * @dev External parameters passed to customize swap behavior
     * @param maxSteps Maximum number of steps allowed in the swap path (limits complexity)
     * @param gasPrice Gas price used for optimizing route selection
     * @param slippageBips Slippage tolerance in basis points (1 bip = 0.01%)
     * @param yakSwapFeeBips Fee charged by the YakRouter for the swap in basis points (1 bip = 0.01%)
     * @custom:validation maxSteps should be reasonable to prevent excessive gas usage (e.g., 2-3)
     * @custom:validation slippageBips should be within reasonable bounds (e.g., 0-1000)
     */
    struct Extras {
        uint256 maxSteps;
        uint256 gasPrice;
        uint256 slippageBips;
        uint256 yakSwapFeeBips;
    }

    /**
     * @notice Internal structure for storing trade execution data
     * @dev Combines YakRouter Trade struct with protocol fee information
     * @param trade YakRouter Trade struct containing path and amount information
     * @param yakSwapFee Fee to be paid to YakRouter for the swap
     */
    struct TradeData {
        Trade trade;
        uint256 yakSwapFeeBips;
    }

    uint256 public constant BIPS_DIVISOR = 10_000;

    /**
     * @notice YakRouter contract used for swap routing and execution
     * @dev Immutable reference to the YakRouter aggregation protocol
     */
    IYakRouter public immutable router;

    /**
     * @notice Creates new YakSwapCell instance
     * @dev Initializes the contract with YakRouter and wrapped native token addresses
     * @param routerAddress Address of the YakRouter aggregation contract
     * @param wrappedNativeToken Address of the wrapped native token (e.g., WAVAX)
     */
    constructor(address owner, address routerAddress, address wrappedNativeToken) Cell(owner, wrappedNativeToken) {
        if (routerAddress == address(0)) {
            revert InvalidArgument();
        }
        router = IYakRouter(routerAddress);
    }

    /**
     * @notice Calculates optimal swap route for given tokens and amount
     * @dev Implements the abstract route() function from Cell contract
     *      Uses YakRouter's findBestPathWithGas for route optimization
     * @param amountIn Amount of input tokens to swap
     * @param tokenIn Address of input token
     * @param tokenOut Address of desired output token
     * @param data ABI-encoded Extras struct containing swap parameters
     * @return trade Encoded TradeData containing optimal path and fees
     * @return gasEstimate Estimated gas cost for executing the swap
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

        TradeData memory tradeData = TradeData({
            trade: Trade({
                amountIn: offer.amounts[0],
                amountOut: (offer.amounts[offer.amounts.length - 1] * (BIPS_DIVISOR - extras.slippageBips)) / BIPS_DIVISOR,
                path: offer.path,
                adapters: offer.adapters
            }),
            yakSwapFeeBips: extras.yakSwapFeeBips
        });
        trade = abi.encode(tradeData);
        gasEstimate = offer.gasEstimate;
    }

    /**
     * @notice Executes token swap through YakRouter
     * @dev Implements the abstract _swap() function from Cell contract
     *      Key implementation points:
     *      1. Decodes trade data and validates output token
     *      2. Tracks balance changes for accurate output amount
     *      3. Handles approval and swap execution with error handling
     *      4. Revokes approval on failure
     * @param token Address of input token
     * @param amount Amount of input tokens
     * @param tradePayload ABI-encoded TradeData containing swap instructions
     * @return success True if swap succeeded, false otherwise
     * @return tokenOut Address of output token (address(0) if failed)
     * @return amountOut Amount of tokens received (0 if failed)
     */
    function _swap(address token, uint256 amount, bytes memory tradePayload)
        internal
        override
        returns (bool success, address tokenOut, uint256 amountOut)
    {
        TradeData memory tradeData = abi.decode(tradePayload, (TradeData));

        tokenOut = tradeData.trade.path.length > 0 ? tradeData.trade.path[tradeData.trade.path.length - 1] : address(0);
        if (tokenOut == address(0)) {
            return (false, address(0), 0);
        }
        uint256 balanceBefore = token == tokenOut
            ? IERC20(tokenOut).balanceOf(address(this)) - amount
            : IERC20(tokenOut).balanceOf(address(this));
        IERC20(token).forceApprove(address(router), amount);
        try IYakRouter(router).swapNoSplit(tradeData.trade, address(this), tradeData.yakSwapFeeBips) {
            success = true;
            amountOut = IERC20(tokenOut).balanceOf(address(this)) - balanceBefore;
        } catch {
            IERC20(token).approve(address(router), 0);
        }
    }
}
