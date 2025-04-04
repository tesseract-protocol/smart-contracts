// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Cell} from "./Cell.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapFactory, IUniswapPair} from "./interfaces/IUniswapV2.sol";
import {UniV2Router} from "./lib/UniV2Router.sol";

/**
 * @title UniV2Cell
 * @notice Implements Uniswap V2-style exchange functionality with multi-hop routing capabilities
 * @dev Inherits from Cell contract to provide swap functionality for Uniswap V2-compatible DEXs
 */
contract UniV2Cell is Cell {
    using SafeERC20 for IERC20;

    error NoRouteFound();
    error InvalidParameters();
    error SlippageExceeded();
    error TooManyHops();
    error InvalidHopToken();
    error MaxHopsExceeded();

    uint256 internal constant FEE_DENOMINATOR = 1e3;
    uint256 public constant MAX_ALLOWED_HOPS = 5;

    uint256 public immutable feeCompliment;
    address public immutable factory;
    uint256 public immutable swapGasEstimate;

    uint256 public maxHops;
    address[] public hopTokens;

    event HopTokensUpdated(address[] newHopTokens);
    event MaxHopsUpdated(uint256 newMaxHops);
    event UniV2CellSwap();

    struct Extras {
        uint256 slippageBips;
    }

    struct Trade {
        address[] path;
        uint256 amountOut;
        uint256 minAmountOut;
    }

    struct Route {
        address[] path;
        uint256 amountOut;
        uint256 hops;
    }

    struct PathState {
        Route[] queue;
        uint256 queueStart;
        uint256 queueEnd;
        address[] visitedTokens;
        uint256 visitedCount;
    }

    /**
     * @notice Initializes the UniV2Cell contract with required parameters
     * @param owner Address of the contract owner
     * @param wrappedNativeToken Address of the wrapped native token (e.g., WAVAX)
     * @param uniV2Factory Address of the Uniswap V2 factory contract
     * @param fee Exchange fee in parts per thousand
     * @param estimatedSwapGas Estimated gas cost for executing a swap
     * @param initialHopTokens Array of tokens allowed as intermediate swap hops
     * @param initialMaxHops Maximum number of intermediate hops allowed in a path
     */
    constructor(
        address owner,
        address wrappedNativeToken,
        address teleporterRegistry,
        uint256 minTeleporterVersion,
        address uniV2Factory,
        uint256 fee,
        uint256 estimatedSwapGas,
        address[] memory initialHopTokens,
        uint256 initialMaxHops
    ) Cell(owner, wrappedNativeToken, teleporterRegistry, minTeleporterVersion) {
        if (uniV2Factory == address(0)) {
            revert InvalidArgument();
        }
        if (initialMaxHops > MAX_ALLOWED_HOPS) {
            revert MaxHopsExceeded();
        }
        if (fee >= FEE_DENOMINATOR) {
            revert InvalidParameters();
        }
        feeCompliment = FEE_DENOMINATOR - fee;
        factory = uniV2Factory;
        swapGasEstimate = estimatedSwapGas;
        _setHopTokens(initialHopTokens);
        maxHops = initialMaxHops;
    }

    /**
     * @notice Updates the list of allowed intermediate hop tokens
     * @param newHopTokens New array of token addresses to be used as hops
     */
    function setHopTokens(address[] calldata newHopTokens) external onlyOwner {
        _setHopTokens(newHopTokens);
    }

    /**
     * @notice Updates the maximum allowed number of intermediate hops
     * @param newMaxHops New maximum hop limit
     */
    function setMaxHops(uint256 newMaxHops) external onlyOwner {
        if (newMaxHops > MAX_ALLOWED_HOPS) {
            revert MaxHopsExceeded();
        }
        maxHops = newMaxHops;
        emit MaxHopsUpdated(newMaxHops);
    }

    /**
     * @notice Internal function to validate and update hop tokens
     * @param newHopTokens Array of new hop token addresses to validate and set
     * @dev Checks for zero addresses and duplicates
     */
    function _setHopTokens(address[] memory newHopTokens) internal {
        for (uint256 i = 0; i < newHopTokens.length; i++) {
            if (newHopTokens[i] == address(0)) {
                revert InvalidHopToken();
            }
            for (uint256 j = i + 1; j < newHopTokens.length; j++) {
                if (newHopTokens[i] == newHopTokens[j]) {
                    revert InvalidHopToken();
                }
            }
        }

        hopTokens = newHopTokens;
        emit HopTokensUpdated(newHopTokens);
    }

    /**
     * @notice Calculates the optimal route for a token swap
     * @param amountIn Amount of input tokens
     * @param tokenIn Address of input token
     * @param tokenOut Address of desired output token
     * @param data Additional swap parameters (encoded Extras struct)
     * @return trade Encoded trade information
     * @return gasEstimate Estimated gas cost for executing the swap
     */
    function route(uint256 amountIn, address tokenIn, address tokenOut, bytes calldata data)
        external
        view
        override
        returns (bytes memory trade, uint256 gasEstimate)
    {
        if (tokenIn == tokenOut || amountIn == 0) {
            revert InvalidParameters();
        }

        (address[] memory path, uint256 amountOut) =
            UniV2Router.findBestPath(factory, feeCompliment, amountIn, tokenIn, tokenOut, hopTokens, maxHops);
        if (path.length == 0 || amountOut == 0) {
            revert NoRouteFound();
        }

        Extras memory extras = abi.decode(data, (Extras));
        trade = abi.encode(
            Trade({
                path: path,
                amountOut: amountOut,
                minAmountOut: (amountOut * (BIPS_DIVISOR - extras.slippageBips)) / BIPS_DIVISOR
            })
        );
        gasEstimate = swapGasEstimate * (path.length - 1);
    }

    /**
     * @notice Executes a token swap along the calculated path
     * @param token Address of input token
     * @param amount Amount of input tokens
     * @param tradePayload Encoded trade parameters
     * @return success Whether the swap was successful
     * @return tokenOut Address of the output token
     * @return amountOut Amount of output tokens received
     */
    function _swap(address token, uint256 amount, bytes memory tradePayload)
        internal
        override
        returns (bool success, address tokenOut, uint256 amountOut)
    {
        Trade memory trade = abi.decode(tradePayload, (Trade));
        if (trade.path.length > maxHops + 1) revert TooManyHops();
        if (trade.path[0] != token) revert InvalidParameters();

        tokenOut = trade.path[trade.path.length - 1];
        if (tokenOut == address(0) || token == tokenOut) {
            return (false, address(0), 0);
        }

        uint256 balanceBefore = IERC20(tokenOut).balanceOf(address(this));

        uint256[] memory amounts = _getAmountsOut(trade.path, amount);

        if (amounts[amounts.length - 1] < trade.minAmountOut) {
            emit CellSwapFailed(token, amount, tokenOut, trade.minAmountOut);
            return (false, address(0), 0);
        }

        for (uint256 i = 0; i < trade.path.length - 1; i++) {
            address currentToken = trade.path[i];
            address nextToken = trade.path[i + 1];
            address pair = IUniswapFactory(factory).getPair(currentToken, nextToken);

            bool isFirst = i == 0;
            bool isLast = i == trade.path.length - 2;

            if (isFirst) {
                IERC20(currentToken).safeTransfer(pair, amounts[i]);
            }

            (uint256 amount0Out, uint256 amount1Out) =
                currentToken < nextToken ? (uint256(0), amounts[i + 1]) : (amounts[i + 1], uint256(0));

            address to = isLast ? address(this) : IUniswapFactory(factory).getPair(nextToken, trade.path[i + 2]);
            IUniswapPair(pair).swap(amount0Out, amount1Out, to, new bytes(0));
        }

        amountOut = IERC20(tokenOut).balanceOf(address(this)) - balanceBefore;
        if (amountOut < trade.minAmountOut) {
            revert SlippageExceeded();
        }

        emit UniV2CellSwap();

        return (true, tokenOut, amountOut);
    }

    /**
     * @notice Calculates the expected output amounts for each swap in a multi-hop path
     * @param path Array of token addresses representing the swap path
     * @param amountIn The amount of input tokens to swap
     * @return amounts Array of output amounts, where amounts[0] is amountIn and
     *                 amounts[i] is the output amount for the i-th swap
     */
    function _getAmountsOut(address[] memory path, uint256 amountIn) internal view returns (uint256[] memory amounts) {
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;

        for (uint256 i = 0; i < path.length - 1; i++) {
            address pair = IUniswapFactory(factory).getPair(path[i], path[i + 1]);
            if (pair == address(0)) revert NoRouteFound();
            amounts[i + 1] = UniV2Router.getAmountOut(pair, path[i], path[i + 1], amounts[i], feeCompliment);
        }
    }
}
