// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Cell} from "./Cell.sol";
import {IDexalotMainnetRFQ} from "./interfaces/IDexalotMainnetRFQ.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWrappedNativeToken} from "@ictt/interfaces/IWrappedNativeToken.sol";

/**
 * @title DexalotSimpleSwapCell
 * @notice Implementation of Cell contract for cross-chain swaps using Dexalot SimpleSwap
 * @dev Concrete implementation of the Cell contract that:
 *      1. Takes signed orders from Dexalot RFQ service
 *      2. Executes swaps through Dexalot's MainnetRFQ contract
 *      3. Handles WAVAX<->AVAX conversions for native token swaps
 */
contract DexalotSimpleSwapCell is Cell {
    using SafeERC20 for IERC20;

    error SlippageExceeded();

    event ValidationFailed(string indexed reason);

    /**
     * @notice Parameters for swap execution through Dexalot
     * @param order The signed order from Dexalot RFQ service containing trade details
     * @param signature The signature validating the order
     * @param minAmountOut Minimum amount of output tokens to receive
     */
    struct TradeParams {
        IDexalotMainnetRFQ.Order order;
        bytes signature;
        uint256 minAmountOut;
    }

    IDexalotMainnetRFQ public immutable mainnetRFQ;
    uint256 public immutable swapGasEstimate;

    /**
     * @notice Creates new DexalotSimpleSwapCell instance
     * @param owner Contract owner address
     * @param mainnetRFQAddress Address of Dexalot's MainnetRFQ contract
     * @param estimatedSwapGas Estimated gas cost for executing a swap
     * @param wrappedNativeToken Address of the wrapped native token (WAVAX)
     */
    constructor(address owner, address mainnetRFQAddress, uint256 estimatedSwapGas, address wrappedNativeToken)
        Cell(owner, wrappedNativeToken)
    {
        if (mainnetRFQAddress == address(0)) {
            revert InvalidArgument();
        }
        mainnetRFQ = IDexalotMainnetRFQ(mainnetRFQAddress);
        swapGasEstimate = estimatedSwapGas;
    }

    /**
     * @notice Route function implementation (required by Cell contract)
     * @dev Since routing is done off-chain through Dexalot's API, this just passes through the trade data
     * @return trade Encoded trade parameters
     * @return gasEstimate Constant gas estimate for swap execution
     */
    function route(uint256, address, address, bytes calldata)
        external
        view
        override
        returns (bytes memory trade, uint256 gasEstimate)
    {
        return ("", swapGasEstimate); // Fixed gas estimate for Dexalot swaps
    }

    /**
     * @notice Executes swap through Dexalot's MainnetRFQ contract
     * @dev Main swap implementation that:
     *      1. Decodes the signed order and signature
     *      2. Validates order parameters
     *      3. Handles WAVAX<->AVAX conversions
     *      4. Executes swap via MainnetRFQ contract
     * @param token Address of input token
     * @param amount Amount of input tokens
     * @param tradePayload Encoded TradeParams containing order and signature
     * @return success True if swap succeeded
     * @return tokenOut Address of output token
     * @return amountOut Amount of output tokens received
     */
    function _swap(address token, uint256 amount, bytes memory tradePayload)
        internal
        override
        returns (bool success, address tokenOut, uint256 amountOut)
    {
        TradeParams memory params = abi.decode(tradePayload, (TradeParams));
        IDexalotMainnetRFQ.Order memory order = params.order;

        if (token != order.takerAsset && !(token == address(wrappedNativeToken) && order.takerAsset == address(0))) {
            emit ValidationFailed("Invalid input token");
            return (false, address(0), 0);
        }
        if (amount != order.takerAmount) {
            emit ValidationFailed("Invalid amounts");
            return (false, address(0), 0);
        }
        if (block.timestamp > order.expiry) {
            emit ValidationFailed("Order expired");
            return (false, address(0), 0);
        }
        if (order.taker != address(this)) {
            emit ValidationFailed("Invalid taker");
            return (false, address(0), 0);
        }

        tokenOut = order.makerAsset == address(0) ? address(wrappedNativeToken) : order.makerAsset;
        uint256 balanceBefore =
            order.makerAsset == address(0) ? address(this).balance : IERC20(tokenOut).balanceOf(address(this));

        uint256 nativeValue;
        if (order.takerAsset == address(0)) {
            wrappedNativeToken.withdraw(amount);
            nativeValue = amount;
        } else {
            IERC20(token).forceApprove(address(mainnetRFQ), amount);
        }

        try IDexalotMainnetRFQ(mainnetRFQ).simpleSwap{value: nativeValue}(order, params.signature) {
            if (order.makerAsset == address(0)) {
                amountOut = address(this).balance - balanceBefore;
                if (amountOut < params.minAmountOut) revert SlippageExceeded();
                wrappedNativeToken.deposit{value: amountOut}();
            } else {
                amountOut = IERC20(tokenOut).balanceOf(address(this)) - balanceBefore;
                if (amountOut < params.minAmountOut) revert SlippageExceeded();
            }
            success = true;
        } catch {
            if (order.takerAsset == address(0)) {
                wrappedNativeToken.deposit{value: nativeValue}();
            } else {
                IERC20(token).approve(address(mainnetRFQ), 0);
            }
            return (false, address(0), 0);
        }
    }
}
