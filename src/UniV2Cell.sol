// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Cell} from "./Cell.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapFactory, IUniswapPair} from "./interfaces/IUniswapV2.sol";

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
    uint256 public constant BIPS_DIVISOR = 10_000;
    uint256 public constant MAX_ALLOWED_HOPS = 5;

    uint256 public immutable feeCompliment;
    address public immutable factory;
    uint256 public immutable swapGasEstimate;

    uint256 public maxHops;
    address[] public hopTokens;

    event HopTokensUpdated(address[] newHopTokens);
    event MaxHopsUpdated(uint256 newMaxHops);

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
        address uniV2Factory,
        uint256 fee,
        uint256 estimatedSwapGas,
        address[] memory initialHopTokens,
        uint256 initialMaxHops
    ) Cell(owner, wrappedNativeToken) {
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

        (address[] memory path, uint256 amountOut) = _findBestPath(amountIn, tokenIn, tokenOut);
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

        return (true, tokenOut, amountOut);
    }

    /**
     * @notice Finds the optimal trading path between two tokens
     * @param amountIn Amount of input tokens
     * @param tokenIn Address of input token
     * @param tokenOut Address of desired output token
     * @return bestPath Array of token addresses representing the optimal path
     * @return bestAmountOut Expected amount of output tokens
     */
    function _findBestPath(uint256 amountIn, address tokenIn, address tokenOut)
        internal
        view
        returns (address[] memory bestPath, uint256 bestAmountOut)
    {
        PathState memory state;
        state.queue = new Route[](maxHops * hopTokens.length + 1);
        state.visitedTokens = new address[](maxHops + 2);
        state.visitedTokens[state.visitedCount++] = tokenIn;

        address directPair = IUniswapFactory(factory).getPair(tokenIn, tokenOut);
        if (directPair != address(0)) {
            bestPath = new address[](2);
            bestPath[0] = tokenIn;
            bestPath[1] = tokenOut;
            bestAmountOut = _getAmountOut(directPair, tokenIn, tokenOut, amountIn);
        }

        address[] memory initialPath = new address[](1);
        initialPath[0] = tokenIn;
        state.queue[state.queueEnd++] = Route({path: initialPath, amountOut: amountIn, hops: 0});

        (address[] memory explorePath, uint256 exploreAmount) = _explorePaths(tokenOut, state);

        if (exploreAmount > bestAmountOut) {
            bestPath = explorePath;
            bestAmountOut = exploreAmount;
        }

        if (bestPath.length == 0) revert NoRouteFound();
        return (bestPath, bestAmountOut);
    }

    /**
     * @notice Core path exploration logic using breadth-first search
     * @param tokenOut Address of desired output token
     * @param state Current path exploration state
     * @return bestPath Array of token addresses representing the optimal path
     * @return bestAmountOut Expected amount of output tokens
     */
    function _explorePaths(address tokenOut, PathState memory state)
        internal
        view
        returns (address[] memory bestPath, uint256 bestAmountOut)
    {
        while (state.queueStart < state.queueEnd) {
            Route memory currentRoute = state.queue[state.queueStart++];
            if (currentRoute.hops >= maxHops) continue;

            address currentToken = currentRoute.path[currentRoute.path.length - 1];

            for (uint256 i = 0; i < hopTokens.length; i++) {
                address hopToken = hopTokens[i];

                if (_isTokenVisited(hopToken, state) || hopToken == currentToken || hopToken == tokenOut) continue;

                address hopPair = IUniswapFactory(factory).getPair(currentToken, hopToken);
                if (hopPair == address(0)) continue;

                uint256 hopAmount = _getAmountOut(hopPair, currentToken, hopToken, currentRoute.amountOut);
                if (hopAmount == 0) continue;

                address finalPair = IUniswapFactory(factory).getPair(hopToken, tokenOut);
                if (finalPair != address(0)) {
                    uint256 finalAmount = _getAmountOut(finalPair, hopToken, tokenOut, hopAmount);
                    if (finalAmount > bestAmountOut) {
                        bestAmountOut = finalAmount;
                        bestPath = _buildPath(currentRoute.path, hopToken, tokenOut);
                    }
                }

                if (currentRoute.hops + 1 < maxHops) {
                    state.queue[state.queueEnd++] = Route({
                        path: _buildPath(currentRoute.path, hopToken),
                        amountOut: hopAmount,
                        hops: currentRoute.hops + 1
                    });

                    if (state.visitedCount < state.visitedTokens.length) {
                        state.visitedTokens[state.visitedCount++] = hopToken;
                    }
                }
            }
        }

        return (bestPath, bestAmountOut);
    }

    /**
     * @notice Creates a new path array by appending tokens to an existing path
     * @param currentPath Current array of token addresses
     * @param newToken Token address to append
     * @param finalToken Final token address to append
     * @return New path array with appended tokens
     */
    function _buildPath(address[] memory currentPath, address newToken, address finalToken)
        internal
        pure
        returns (address[] memory)
    {
        address[] memory newPath = new address[](currentPath.length + 2);

        for (uint256 i = 0; i < currentPath.length; i++) {
            newPath[i] = currentPath[i];
        }
        newPath[currentPath.length] = newToken;
        newPath[currentPath.length + 1] = finalToken;

        return newPath;
    }

    /**
     * @notice Creates a new path array by appending a single token
     * @param currentPath Current array of token addresses
     * @param newToken Token address to append
     * @return New path array with appended token
     */
    function _buildPath(address[] memory currentPath, address newToken) internal pure returns (address[] memory) {
        address[] memory newPath = new address[](currentPath.length + 1);

        for (uint256 i = 0; i < currentPath.length; i++) {
            newPath[i] = currentPath[i];
        }
        newPath[currentPath.length] = newToken;

        return newPath;
    }

    /**
     * @notice Checks if a token has already been visited in the current path
     * @param token Token address to check
     * @param state Current path exploration state
     * @return bool True if token has been visited
     */
    function _isTokenVisited(address token, PathState memory state) internal pure returns (bool) {
        for (uint256 i = 0; i < state.visitedCount; i++) {
            if (state.visitedTokens[i] == token) return true;
        }
        return false;
    }

    /**
     * @notice Calculates the output amount for a single swap
     * @param pair Address of the trading pair contract
     * @param tokenIn Address of input token
     * @param tokenOut Address of output token
     * @param amountIn Amount of input tokens
     * @return amountOut Expected amount of output tokens
     */
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
            amounts[i + 1] = _getAmountOut(pair, path[i], path[i + 1], amounts[i]);
        }
    }
}
