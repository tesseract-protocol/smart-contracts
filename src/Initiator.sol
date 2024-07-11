// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./interfaces/ISwapData.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@avalanche-interchain-token-transfer/interfaces/IERC20TokenTransferrer.sol";

contract Initiator {
    uint256 constant GAS_LIMIT_BRIDGE_HOP = 350_000;

    address public immutable primaryFeeToken;

    constructor(address primaryFeeTokenAddress) {
        primaryFeeToken = primaryFeeTokenAddress;
    }

    function crossChainSwap(SwapData memory swapData) external {
        address tokenIn = swapData.bridgePath[0].from;
        IERC20(tokenIn).transferFrom(msg.sender, address(this), swapData.trade.amountIn);
        SendAndCallInput memory input = SendAndCallInput({
            destinationBlockchainID: swapData.bridgePath[0].destinationBlockchainId,
            destinationTokenTransferrerAddress: swapData.bridgePath[0].to,
            recipientContract: swapData.executor,
            recipientPayload: abi.encode(swapData),
            requiredGasLimit: swapData.gasLimit + (swapData.bridgePath.length * GAS_LIMIT_BRIDGE_HOP),
            recipientGasLimit: swapData.gasLimit,
            multiHopFallback: address(0),
            fallbackRecipient: msg.sender,
            primaryFeeTokenAddress: primaryFeeToken,
            primaryFee: 0,
            secondaryFee: 0
        });
        IERC20(tokenIn).approve(tokenIn, swapData.trade.amountIn);
        IERC20TokenTransferrer(tokenIn).sendAndCall(input, swapData.trade.amountIn);
    }
}
