// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./interfaces/ISwapData.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@avalanche-interchain-token-transfer/interfaces/IERC20TokenTransferrer.sol";
import "teleporter/contracts/src/Teleporter/upgrades/TeleporterRegistry.sol";
import "avalanche-interchain-token-transfer/contracts/src/interfaces/IERC20SendAndCallReceiver.sol";

contract Executor is IERC20SendAndCallReceiver {
    uint256 constant GAS_LIMIT_BRIDGING = 350_000;

    TeleporterRegistry public immutable teleporterRegistry;
    IYakRouter public immutable router;
    address public immutable primaryFeeToken;

    constructor(address teleporterRegistryAddress, address routerAddress, address primaryFeeTokenAddress) {
        require(teleporterRegistryAddress > address(0), "Executor: invalid teleporter registry address");

        teleporterRegistry = TeleporterRegistry(teleporterRegistryAddress);
        router = IYakRouter(routerAddress);
        primaryFeeToken = primaryFeeTokenAddress;
    }

    function receiveTokens(
        bytes32 sourceBlockchainID,
        address originTokenTransferrerAddress,
        address originSenderAddress,
        address token,
        uint256 amount,
        bytes calldata payload
    ) external override {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        SwapData memory swapData = abi.decode(payload, (SwapData));
        address tokenOut = swapData.trade.path[swapData.trade.path.length - 1];
        uint256 balanceBefore = IERC20(tokenOut).balanceOf(address(this));
        IERC20(swapData.trade.path[0]).approve(address(router), swapData.trade.amountIn);
        IYakRouter(router).swapNoSplit(swapData.trade, address(this), 0);
        uint256 amountOut = IERC20(tokenOut).balanceOf(address(this)) - balanceBefore;
        SendTokensInput memory input = SendTokensInput({
            destinationBlockchainID: swapData.bridgePath[1].destinationBlockchainId,
            destinationTokenTransferrerAddress: swapData.bridgePath[1].to,
            recipient: swapData.receiver,
            primaryFeeTokenAddress: primaryFeeToken,
            primaryFee: 0,
            secondaryFee: 0,
            requiredGasLimit: GAS_LIMIT_BRIDGING,
            multiHopFallback: address(0)
        });

        IERC20(tokenOut).approve(swapData.bridgePath[1].from, amountOut);
        IERC20TokenTransferrer(swapData.bridgePath[1].from).send(input, amountOut);
    }
}
