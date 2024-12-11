// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Cell} from "./Cell.sol";
import {CellPayload} from "./interfaces/ICell.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapFactory, IUniswapPair} from "./interfaces/IUniswapV2.sol";

/// @title UniV2Cell
/// @notice A Cell implementation for Uniswap V2-style exchanges with multi-hop routing
/// @dev Inherits from Cell contract and implements swap functionality for Uniswap V2
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

    struct Route {
        address token;
        uint256 amountOut;
        uint256 hops;
    }

    struct Extras {
        uint256 slippageBips;
    }

    struct Trade {
        address[] path;
        uint256 amountOut;
        uint256 minAmountOut;
    }

    struct PathState {
        address[] bestPath;
        uint256 bestAmountOut;
        Route[] queue;
        uint256 queueStart;
        uint256 queueEnd;
        address[] visitedTokens;
        uint256 visitedCount;
    }

    /// @notice Constructs the UniV2Cell contract
    /// @param owner The address of the contract owner
    /// @param wrappedNativeToken The address of the wrapped native token (e.g., WAVAX)
    /// @param uniV2Factory The address of the Uniswap V2 factory
    /// @param fee The fee for the exchange (in parts per thousand)
    /// @param estimatedSwapGas The estimated gas cost for a swap
    /// @param _hopTokens Array of tokens to be used as intermediate hops
    /// @param _maxHops Maximum number of hops allowed in a path
    constructor(
        address owner,
        address wrappedNativeToken,
        address uniV2Factory,
        uint256 fee,
        uint256 estimatedSwapGas,
        address[] memory _hopTokens,
        uint256 _maxHops
    ) Cell(owner, wrappedNativeToken) {
        if (uniV2Factory == address(0)) {
            revert InvalidArgument();
        }
        if (_maxHops > MAX_ALLOWED_HOPS) {
            revert MaxHopsExceeded();
        }
        feeCompliment = FEE_DENOMINATOR - fee;
        factory = uniV2Factory;
        swapGasEstimate = estimatedSwapGas;
        _setHopTokens(_hopTokens);
        maxHops = _maxHops;
    }

    /// @notice Updates the list of tokens that can be used as intermediate hops
    /// @param newHopTokens New array of hop token addresses
    /// @dev Only callable by owner
    function setHopTokens(address[] calldata newHopTokens) external onlyOwner {
        _setHopTokens(newHopTokens);
    }

    /// @notice Updates the maximum number of hops allowed in a path
    /// @param newMaxHops New maximum number of hops
    /// @dev Only callable by owner
    function setMaxHops(uint256 newMaxHops) external onlyOwner {
        if (newMaxHops > MAX_ALLOWED_HOPS) {
            revert MaxHopsExceeded();
        }
        maxHops = newMaxHops;
        emit MaxHopsUpdated(newMaxHops);
    }

    /// @notice Internal function to validate and set hop tokens
    /// @param newHopTokens New array of hop token addresses
    function _setHopTokens(address[] memory newHopTokens) internal {
        // Validate new hop tokens
        for (uint256 i = 0; i < newHopTokens.length; i++) {
            if (newHopTokens[i] == address(0)) {
                revert InvalidHopToken();
            }
            // Check for duplicates
            for (uint256 j = i + 1; j < newHopTokens.length; j++) {
                if (newHopTokens[i] == newHopTokens[j]) {
                    revert InvalidHopToken();
                }
            }
        }

        hopTokens = newHopTokens;
        emit HopTokensUpdated(newHopTokens);
    }

    /// @notice Returns the current list of hop tokens
    /// @return Array of hop token addresses
    function getHopTokens() external view returns (address[] memory) {
        return hopTokens;
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

        (address[] memory path, uint256 amountOut) = findBestPath(amountIn, tokenIn, tokenOut);
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
        if (trade.path.length > maxHops + 1) revert TooManyHops();
        if (trade.path[0] != token) revert InvalidParameters();

        tokenOut = trade.path[trade.path.length - 1];
        if (tokenOut == address(0) || token == tokenOut) {
            return (false, address(0), 0);
        }

        uint256 balanceBefore = IERC20(tokenOut).balanceOf(address(this));

        // Execute the multi-hop swap
        uint256[] memory amounts = getAmountsOut(trade.path, amount);
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

    /// @notice Finds the best path between two tokens using the configured hop tokens
    function findBestPath(uint256 amountIn, address tokenIn, address tokenOut)
        internal
        view
        returns (address[] memory bestPath, uint256 bestAmountOut)
    {
        // Try direct path first
        address directPair = IUniswapFactory(factory).getPair(tokenIn, tokenOut);
        if (directPair != address(0)) {
            bestPath = new address[](2);
            bestPath[0] = tokenIn;
            bestPath[1] = tokenOut;
            bestAmountOut = _getAmountOut(directPair, tokenIn, tokenOut, amountIn);
            return (bestPath, bestAmountOut);
        }

        PathState memory state;
        state.queue = new Route[](maxHops * hopTokens.length + 1);
        state.visitedTokens = new address[](maxHops + 2);

        state.queue[state.queueEnd++] = Route({token: tokenIn, amountOut: amountIn, hops: 0});
        state.visitedTokens[state.visitedCount++] = tokenIn;

        return _explorePaths(tokenIn, tokenOut, state);
    }

    function _explorePaths(address tokenIn, address tokenOut, PathState memory state)
        internal
        view
        returns (address[] memory bestPath, uint256 bestAmountOut)
    {
        bestPath = state.bestPath;
        bestAmountOut = state.bestAmountOut;

        while (state.queueStart < state.queueEnd && state.queueStart < state.queue.length) {
            Route memory currentRoute = state.queue[state.queueStart++];

            if (currentRoute.hops >= maxHops) continue;

            (address[] memory newPath, uint256 newAmount) = _exploreHopTokens(tokenIn, tokenOut, currentRoute, state);

            if (newAmount > bestAmountOut) {
                bestPath = newPath;
                bestAmountOut = newAmount;
            }
        }
    }

    /// @notice Explores all possible hop tokens for the current route
    function _exploreHopTokens(address tokenIn, address tokenOut, Route memory currentRoute, PathState memory state)
        internal
        view
        returns (address[] memory bestPath, uint256 bestAmountOut)
    {
        bestPath = state.bestPath;
        bestAmountOut = state.bestAmountOut;

        for (uint256 i = 0; i < hopTokens.length; i++) {
            address hopToken = hopTokens[i];

            if (_isTokenVisited(hopToken, state) || hopToken == currentRoute.token) continue;

            (bestPath, bestAmountOut) =
                _tryHopToken(tokenIn, tokenOut, hopToken, currentRoute, state, bestPath, bestAmountOut);
        }
    }

    /// @notice Checks if a token has been visited
    function _isTokenVisited(address token, PathState memory state) internal pure returns (bool) {
        for (uint256 i = 0; i < state.visitedCount; i++) {
            if (state.visitedTokens[i] == token) {
                return true;
            }
        }
        return false;
    }

    function _tryHopToken(
        address tokenIn,
        address tokenOut,
        address hopToken,
        Route memory currentRoute,
        PathState memory state,
        address[] memory bestPath,
        uint256 bestAmountOut
    ) internal view returns (address[] memory, uint256) {
        if (hopToken == tokenOut) return (bestPath, bestAmountOut);

        address pairCurrent = IUniswapFactory(factory).getPair(currentRoute.token, hopToken);
        if (pairCurrent == address(0)) {
            return (bestPath, bestAmountOut);
        }

        uint256 hopAmount = _getAmountOut(pairCurrent, currentRoute.token, hopToken, currentRoute.amountOut);
        if (hopAmount == 0) {
            return (bestPath, bestAmountOut);
        }

        // Try to complete the route through this hop
        address pairTarget = IUniswapFactory(factory).getPair(hopToken, tokenOut);
        if (pairTarget != address(0)) {
            uint256 finalAmount = _getAmountOut(pairTarget, hopToken, tokenOut, hopAmount);
            if (finalAmount > bestAmountOut) {
                bestAmountOut = finalAmount;
                bestPath = new address[](currentRoute.hops + 3);
                bestPath[0] = tokenIn;
                bestPath[currentRoute.hops + 1] = hopToken;
                bestPath[currentRoute.hops + 2] = tokenOut;
            }
        }

        // Add to queue for further exploration if not at max hops
        if (currentRoute.hops + 1 < maxHops) {
            state.queue[state.queueEnd++] = Route({token: hopToken, amountOut: hopAmount, hops: currentRoute.hops + 1});
        }

        if (state.visitedCount < state.visitedTokens.length) {
            state.visitedTokens[state.visitedCount++] = hopToken;
        }

        return (bestPath, bestAmountOut);
    }

    /// @notice Calculates amounts out along a path
    /// @param path The token path
    /// @param amountIn The input amount
    /// @return amounts Array of amounts out for each hop
    function getAmountsOut(address[] memory path, uint256 amountIn) internal view returns (uint256[] memory amounts) {
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;

        for (uint256 i = 0; i < path.length - 1; i++) {
            address pair = IUniswapFactory(factory).getPair(path[i], path[i + 1]);
            if (pair == address(0)) revert NoRouteFound();
            amounts[i + 1] = _getAmountOut(pair, path[i], path[i + 1], amounts[i]);
        }
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
}
