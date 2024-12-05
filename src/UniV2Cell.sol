// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Cell} from "./Cell.sol";
import {CellPayload} from "./interfaces/ICell.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapFactory, IUniswapPair} from "./interfaces/IUniswapV2.sol";

/// @title UniV2Cell
/// @notice A Cell implementation for Uniswap V2-style exchanges
/// @dev Inherits from Cell contract and implements swap functionality for Uniswap V2
contract UniV2Cell is Cell {
    using SafeERC20 for IERC20;

    error NoRouteFound();
    error InvalidParameters();
    error SlippageExceeded();

    uint256 internal constant FEE_DENOMINATOR = 1e3;
    uint256 public immutable feeCompliment;
    address public immutable factory;
    uint256 public immutable swapGasEstimate;

    struct Extras {
        uint256 slippageBips;
    }

    struct Trade {
        address tokenOut;
        uint256 amountOut;
        uint256 minAmountOut;
    }

    /// @notice Constructs the UniV2Cell contract
    /// @param owner The address of the contract owner
    /// @param wrappedNativeToken The address of the wrapped native token (e.g., WAVAX)
    /// @param uniV2Factory The address of the Uniswap V2 factory
    /// @param fee The fee for the exchange (in parts per thousand)
    /// @param estimatedSwapGas The estimated gas cost for a swap
    constructor(address owner, address wrappedNativeToken, address uniV2Factory, uint256 fee, uint256 estimatedSwapGas)
        Cell(owner, wrappedNativeToken)
    {
        if (uniV2Factory == address(0)) {
            revert InvalidArgument();
        }
        feeCompliment = FEE_DENOMINATOR - fee;
        factory = uniV2Factory;
        swapGasEstimate = estimatedSwapGas;
    }

    /// @notice Calculates the output amount for a given input amount and pair
    /// @param pair The address of the Uniswap V2 pair
    /// @param tokenIn The address of the input token
    /// @param tokenOut The address of the output token
    /// @param amountIn The input amount
    /// @return amountOut The calculated output amount
    function _getAmountOut(address pair, address tokenIn, address tokenOut, uint256 amountIn)
        internal
        view
        returns (uint256 amountOut)
    {
        (uint256 r0, uint256 r1,) = IUniswapPair(pair).getReserves();
        (uint256 reserveIn, uint256 reserveOut) = tokenIn < tokenOut ? (r0, r1) : (r1, r0);
        uint256 amountInWithFee = amountIn * feeCompliment;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * FEE_DENOMINATOR + amountInWithFee;
        amountOut = numerator / denominator;
    }

    /// @notice Calculates the route for a swap
    /// @param amountIn The input amount
    /// @param tokenIn The address of the input token
    /// @param tokenOut The address of the output token
    /// @param data Additional data for the swap (encoded Extras struct)
    /// @return trade Encoded trade information
    /// @return gasEstimate Estimated gas cost for the swap
    function route(uint256 amountIn, address tokenIn, address tokenOut, bytes calldata data)
        external
        view
        override
        returns (bytes memory trade, uint256 gasEstimate)
    {
        if (tokenIn == tokenOut || amountIn == 0) {
            revert InvalidParameters();
        }
        address pair = IUniswapFactory(factory).getPair(tokenIn, tokenOut);
        if (pair == address(0)) {
            revert NoRouteFound();
        }

        uint256 amountOut = _getAmountOut(pair, tokenIn, tokenOut, amountIn);
        if (amountOut > 0) {
            Extras memory extras = abi.decode(data, (Extras));
            trade = abi.encode(
                Trade({
                    tokenOut: tokenOut,
                    amountOut: amountOut,
                    minAmountOut: (amountOut * (BIPS_DIVISOR - extras.slippageBips)) / BIPS_DIVISOR
                })
            );
            gasEstimate = swapGasEstimate;
        } else {
            revert NoRouteFound();
        }
    }

    /// @notice Executes a swap
    /// @param token The address of the input token
    /// @param amount The input amount
    /// @param tradePayload Encoded trade information
    /// @return success Whether the swap was successful
    /// @return tokenOut The address of the output token
    /// @return amountOut The amount of tokens received
    function _swap(address token, uint256 amount, bytes memory tradePayload)
        internal
        override
        returns (bool success, address tokenOut, uint256 amountOut)
    {
        Trade memory trade = abi.decode(tradePayload, (Trade));

        tokenOut = trade.tokenOut;
        if (tokenOut == address(0) || token == tokenOut) {
            return (false, address(0), 0);
        }

        uint256 balanceBefore = IERC20(tokenOut).balanceOf(address(this));

        address pair = IUniswapFactory(factory).getPair(token, tokenOut);
        amountOut = _getAmountOut(pair, token, tokenOut, amount);
        if (amountOut < trade.minAmountOut) {
            return (false, address(0), 0);
        }

        (uint256 amount0Out, uint256 amount1Out) =
            (token < tokenOut) ? (uint256(0), amountOut) : (amountOut, uint256(0));
        IERC20(token).safeTransfer(pair, amount);
        IUniswapPair(pair).swap(amount0Out, amount1Out, address(this), new bytes(0));

        amountOut = IERC20(tokenOut).balanceOf(address(this)) - balanceBefore;
        if (amountOut < trade.minAmountOut) {
            revert SlippageExceeded();
        }

        return (true, tokenOut, amountOut);
    }
}
