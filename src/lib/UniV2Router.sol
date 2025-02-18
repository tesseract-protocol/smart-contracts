// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IUniswapFactory, IUniswapPair} from "../interfaces/IUniswapV2.sol";

library UniV2Router {
    error NoRouteFound();

    struct PathState {
        address[] visitedTokens;
        uint256 visitedCount;
        uint256 bestAmount;
        address[] bestPath;
    }

    struct ExploreParams {
        address factory;
        uint256 feeCompliment;
        address tokenOut;
        address[] hopTokens;
        uint256 maxHops;
    }

    function findBestPath(
        address factory,
        uint256 feeCompliment,
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        address[] memory hopTokens,
        uint256 maxHops
    ) public view returns (address[] memory bestPath, uint256 bestAmountOut) {
        // Try direct path first
        address directPair = IUniswapFactory(factory).getPair(tokenIn, tokenOut);
        if (directPair != address(0)) {
            bestPath = new address[](2);
            bestPath[0] = tokenIn;
            bestPath[1] = tokenOut;
            bestAmountOut = getAmountOut(directPair, tokenIn, tokenOut, amountIn, feeCompliment);
        }

        // Setup initial state and params
        PathState memory state;
        state.visitedTokens = new address[](maxHops + 2);
        state.visitedTokens[0] = tokenIn;
        state.visitedCount = 1;
        state.bestAmount = bestAmountOut;

        ExploreParams memory params;
        params.factory = factory;
        params.feeCompliment = feeCompliment;
        params.tokenOut = tokenOut;
        params.hopTokens = hopTokens;
        params.maxHops = maxHops;

        // Start exploration with initial path
        address[] memory path = new address[](1);
        path[0] = tokenIn;

        _explore(params, path, 0, amountIn, state);

        if (state.bestAmount > bestAmountOut) {
            bestPath = state.bestPath;
            bestAmountOut = state.bestAmount;
        }

        if (bestPath.length == 0) revert NoRouteFound();
        return (bestPath, bestAmountOut);
    }

    function _explore(
        ExploreParams memory params,
        address[] memory path,
        uint256 depth,
        uint256 amountIn,
        PathState memory state
    ) internal view {
        if (depth >= params.maxHops) return;

        address currentToken = path[path.length - 1];
        _tryHopTokens(params, path, depth, amountIn, currentToken, state);
    }

    function _tryHopTokens(
        ExploreParams memory params,
        address[] memory path,
        uint256 depth,
        uint256 amountIn,
        address currentToken,
        PathState memory state
    ) internal view {
        for (uint256 i = 0; i < params.hopTokens.length; i++) {
            address hopToken = params.hopTokens[i];

            if (_shouldSkipToken(hopToken, currentToken, params.tokenOut, state)) {
                continue;
            }

            _processHopToken(params, path, depth, amountIn, currentToken, hopToken, state);
        }
    }

    function _shouldSkipToken(address hopToken, address currentToken, address tokenOut, PathState memory state)
        internal
        pure
        returns (bool)
    {
        if (hopToken == currentToken || hopToken == tokenOut) {
            return true;
        }

        for (uint256 i = 0; i < state.visitedCount; i++) {
            if (state.visitedTokens[i] == hopToken) {
                return true;
            }
        }

        return false;
    }

    function _processHopToken(
        ExploreParams memory params,
        address[] memory path,
        uint256 depth,
        uint256 amountIn,
        address currentToken,
        address hopToken,
        PathState memory state
    ) internal view {
        address hopPair = IUniswapFactory(params.factory).getPair(currentToken, hopToken);
        if (hopPair == address(0)) return;

        uint256 hopAmount = getAmountOut(hopPair, currentToken, hopToken, amountIn, params.feeCompliment);
        if (hopAmount == 0) return;

        _tryFinalPath(params, path, hopToken, hopAmount, state);

        if (depth + 1 < params.maxHops) {
            _continueExploration(params, path, depth, hopToken, hopAmount, state);
        }
    }

    function _tryFinalPath(
        ExploreParams memory params,
        address[] memory path,
        address hopToken,
        uint256 hopAmount,
        PathState memory state
    ) internal view {
        address finalPair = IUniswapFactory(params.factory).getPair(hopToken, params.tokenOut);
        if (finalPair == address(0)) return;

        uint256 finalAmount = getAmountOut(finalPair, hopToken, params.tokenOut, hopAmount, params.feeCompliment);
        if (finalAmount <= state.bestAmount) return;

        state.bestAmount = finalAmount;
        state.bestPath = _buildFinalPath(path, hopToken, params.tokenOut);
    }

    function _continueExploration(
        ExploreParams memory params,
        address[] memory path,
        uint256 depth,
        address hopToken,
        uint256 hopAmount,
        PathState memory state
    ) internal view {
        state.visitedTokens[state.visitedCount++] = hopToken;

        address[] memory newPath = _buildPath(path, hopToken);
        _explore(params, newPath, depth + 1, hopAmount, state);

        state.visitedCount--;
    }

    function getAmountOut(address pair, address tokenIn, address tokenOut, uint256 amountIn, uint256 feeCompliment)
        public
        view
        returns (uint256)
    {
        (uint256 r0, uint256 r1,) = IUniswapPair(pair).getReserves();
        (uint256 reserveIn, uint256 reserveOut) = tokenIn < tokenOut ? (r0, r1) : (r1, r0);

        uint256 amountInWithFee = amountIn * feeCompliment;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        return numerator / denominator;
    }

    function _buildPath(address[] memory currentPath, address newToken) internal pure returns (address[] memory) {
        address[] memory newPath = new address[](currentPath.length + 1);
        for (uint256 i = 0; i < currentPath.length; i++) {
            newPath[i] = currentPath[i];
        }
        newPath[currentPath.length] = newToken;
        return newPath;
    }

    function _buildFinalPath(address[] memory currentPath, address hopToken, address finalToken)
        internal
        pure
        returns (address[] memory)
    {
        address[] memory newPath = new address[](currentPath.length + 2);
        for (uint256 i = 0; i < currentPath.length; i++) {
            newPath[i] = currentPath[i];
        }
        newPath[currentPath.length] = hopToken;
        newPath[currentPath.length + 1] = finalToken;
        return newPath;
    }
}
