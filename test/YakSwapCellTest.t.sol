// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./BaseTest.t.sol";
import "./../src/YakSwapCell.sol";

contract YakSwapCellTest is BaseTest {
    address public YAK_SWAP_ROUTER = 0xC4729E56b831d74bBc18797e0e17A295fA77488c;

    function test_ERC20_ERC20_SwapAndTransfer() public {
        YakSwapCell cell =
            new YakSwapCell(vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, YAK_SWAP_ROUTER);

        uint256 amountIn = 100e18;
        YakSwapCell.Extras memory extras =
            YakSwapCell.Extras({maxSteps: 2, gasPrice: 25e9, slippageBips: 100, yakSwapFeeBips: 0});
        (bytes memory trade, uint256 gasEstimate) = cell.route(amountIn, WAVAX, USDC, abi.encode(extras));
        YakSwapCell.TradeData memory decodedTrade = abi.decode(trade, (YakSwapCell.TradeData));

        vm.assertGt(decodedTrade.trade.amountOut, 0);

        Hop[] memory hops = new Hop[](1);
        hops[0] = Hop({
            action: Action.SwapAndTransfer,
            requiredGasLimit: gasEstimate + 450_000,
            recipientGasLimit: gasEstimate,
            trade: trade,
            bridgePath: BridgePath({
                sourceBridgeIsNative: false,
                bridgeSourceChain: address(0),
                bridgeDestinationChain: address(0),
                cellDestinationChain: address(0),
                destinationBlockchainID: "",
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions = Instructions({
            receiver: vm.addr(123),
            payableReceiver: true,
            rollbackTeleporterFee: 0,
            rollbackGasLimit: 450_000,
            hops: hops,
            sourceId: 1
        });

        CellPayload memory payload = CellPayload({
            tesseractID: "",
            instructions: instructions,
            sourceBlockchainID: "",
            rollbackDestination: address(0)
        });

        mockReceiveTokens(address(cell), address(wavaxTokenHome), amountIn, payload);

        vm.assertApproxEqRel(IERC20(USDC).balanceOf(vm.addr(123)), decodedTrade.trade.amountOut, 0.1e18);
    }

    function test_Native_ERC20_SwapAndTransfer() public {
        YakSwapCell cell =
            new YakSwapCell(vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, YAK_SWAP_ROUTER);

        uint256 amountIn = 10e18;
        YakSwapCell.Extras memory extras =
            YakSwapCell.Extras({maxSteps: 2, gasPrice: 25e9, slippageBips: 100, yakSwapFeeBips: 0});
        (bytes memory trade, uint256 gasEstimate) = cell.route(amountIn, WAVAX, USDC, abi.encode(extras));
        YakSwapCell.TradeData memory decodedTrade = abi.decode(trade, (YakSwapCell.TradeData));

        vm.assertGt(decodedTrade.trade.amountOut, 0);

        Hop[] memory hops = new Hop[](1);
        hops[0] = Hop({
            action: Action.SwapAndTransfer,
            requiredGasLimit: gasEstimate + 450_000,
            recipientGasLimit: gasEstimate,
            trade: trade,
            bridgePath: BridgePath({
                sourceBridgeIsNative: false,
                bridgeSourceChain: address(0),
                bridgeDestinationChain: address(0),
                cellDestinationChain: address(0),
                destinationBlockchainID: "",
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions = Instructions({
            rollbackTeleporterFee: 0,
            rollbackGasLimit: 450_000,
            receiver: vm.addr(123),
            payableReceiver: true,
            hops: hops,
            sourceId: 1
        });

        CellPayload memory payload = CellPayload({
            tesseractID: "",
            instructions: instructions,
            sourceBlockchainID: "",
            rollbackDestination: address(0)
        });

        mockReceiveNative(address(cell), amountIn, payload);

        vm.assertApproxEqRel(IERC20(USDC).balanceOf(vm.addr(123)), decodedTrade.trade.amountOut, 0.1e18);
    }

    function test_ERC20_Native_SwapAndTransfer() public {
        YakSwapCell cell =
            new YakSwapCell(vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, YAK_SWAP_ROUTER);

        uint256 amountIn = 1000e6;
        YakSwapCell.Extras memory extras =
            YakSwapCell.Extras({maxSteps: 2, gasPrice: 25e9, slippageBips: 100, yakSwapFeeBips: 0});
        (bytes memory trade, uint256 gasEstimate) = cell.route(amountIn, USDC, WAVAX, abi.encode(extras));
        YakSwapCell.TradeData memory decodedTrade = abi.decode(trade, (YakSwapCell.TradeData));

        vm.assertGt(decodedTrade.trade.amountOut, 0);

        Hop[] memory hops = new Hop[](1);
        hops[0] = Hop({
            action: Action.SwapAndTransfer,
            requiredGasLimit: gasEstimate + 450_000,
            recipientGasLimit: gasEstimate,
            trade: trade,
            bridgePath: BridgePath({
                sourceBridgeIsNative: false,
                bridgeSourceChain: address(0),
                bridgeDestinationChain: address(0),
                cellDestinationChain: address(0),
                destinationBlockchainID: "",
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions = Instructions({
            rollbackTeleporterFee: 0,
            rollbackGasLimit: 450_000,
            receiver: vm.addr(123),
            payableReceiver: true,
            hops: hops,
            sourceId: 1
        });

        CellPayload memory payload = CellPayload({
            tesseractID: "",
            instructions: instructions,
            sourceBlockchainID: "",
            rollbackDestination: address(0)
        });

        mockReceiveTokens(address(cell), address(usdcTokenHome), amountIn, payload);

        vm.assertApproxEqRel(address(vm.addr(123)).balance, decodedTrade.trade.amountOut, 0.1e18);
    }

    function test_ERC20_ERC20_Hop() public {
        YakSwapCell cell =
            new YakSwapCell(vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, YAK_SWAP_ROUTER);

        Hop[] memory hops = new Hop[](1);
        hops[0] = Hop({
            action: Action.Hop,
            requiredGasLimit: 900_000,
            recipientGasLimit: 450_000,
            trade: "",
            bridgePath: BridgePath({
                sourceBridgeIsNative: false,
                bridgeSourceChain: address(usdcTokenHome),
                bridgeDestinationChain: randomRemoteAddress,
                cellDestinationChain: vm.addr(9876),
                destinationBlockchainID: REMOTE_BLOCKCHAIN_ID,
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions = Instructions({
            rollbackTeleporterFee: 0,
            rollbackGasLimit: 450_000,
            receiver: vm.addr(123),
            payableReceiver: true,
            hops: hops,
            sourceId: 1
        });

        CellPayload memory payload = CellPayload({
            tesseractID: "",
            instructions: instructions,
            sourceBlockchainID: "",
            rollbackDestination: address(0)
        });

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveTokens(address(cell), address(usdcTokenHome), 1000e6, payload);
    }

    function test_ERC20_Native_Hop() public {
        YakSwapCell cell =
            new YakSwapCell(vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, YAK_SWAP_ROUTER);

        Hop[] memory hops = new Hop[](1);
        hops[0] = Hop({
            action: Action.Hop,
            requiredGasLimit: 900_000,
            recipientGasLimit: 450_000,
            trade: "",
            bridgePath: BridgePath({
                sourceBridgeIsNative: true,
                bridgeSourceChain: address(nativeTokenHome),
                bridgeDestinationChain: randomRemoteAddress,
                cellDestinationChain: vm.addr(9876),
                destinationBlockchainID: REMOTE_BLOCKCHAIN_ID,
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions = Instructions({
            rollbackTeleporterFee: 0,
            rollbackGasLimit: 450_000,
            receiver: vm.addr(123),
            payableReceiver: true,
            hops: hops,
            sourceId: 1
        });

        CellPayload memory payload = CellPayload({
            tesseractID: "",
            instructions: instructions,
            sourceBlockchainID: "",
            rollbackDestination: address(0)
        });

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveTokens(address(cell), address(wavaxTokenHome), 10e18, payload);
    }

    function test_Native_ERC20_Hop() public {
        YakSwapCell cell =
            new YakSwapCell(vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, YAK_SWAP_ROUTER);

        Hop[] memory hops = new Hop[](1);
        hops[0] = Hop({
            action: Action.Hop,
            requiredGasLimit: 900_000,
            recipientGasLimit: 450_000,
            trade: "",
            bridgePath: BridgePath({
                sourceBridgeIsNative: false,
                bridgeSourceChain: address(wavaxTokenHome),
                bridgeDestinationChain: randomRemoteAddress,
                cellDestinationChain: vm.addr(9876),
                destinationBlockchainID: REMOTE_BLOCKCHAIN_ID,
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions = Instructions({
            rollbackTeleporterFee: 0,
            rollbackGasLimit: 450_000,
            receiver: vm.addr(123),
            payableReceiver: true,
            hops: hops,
            sourceId: 1
        });

        CellPayload memory payload = CellPayload({
            tesseractID: "",
            instructions: instructions,
            sourceBlockchainID: "",
            rollbackDestination: address(0)
        });

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveNative(address(cell), 10e18, payload);
    }

    function test_ERC20_ERC20_HopAndCall() public {
        YakSwapCell cell =
            new YakSwapCell(vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, YAK_SWAP_ROUTER);

        Hop[] memory hops = new Hop[](1);
        hops[0] = Hop({
            action: Action.HopAndCall,
            requiredGasLimit: 900_000,
            recipientGasLimit: 450_000,
            trade: "",
            bridgePath: BridgePath({
                sourceBridgeIsNative: false,
                bridgeSourceChain: address(wavaxTokenHome),
                bridgeDestinationChain: randomRemoteAddress,
                cellDestinationChain: vm.addr(9876),
                destinationBlockchainID: REMOTE_BLOCKCHAIN_ID,
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions = Instructions({
            rollbackTeleporterFee: 0,
            rollbackGasLimit: 450_000,
            receiver: vm.addr(123),
            payableReceiver: true,
            hops: hops,
            sourceId: 1
        });

        CellPayload memory payload = CellPayload({
            tesseractID: "",
            instructions: instructions,
            sourceBlockchainID: "",
            rollbackDestination: address(0)
        });

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveTokens(address(cell), address(wavaxTokenHome), 100e18, payload);
    }

    function test_ERC20_Native_HopAndCall() public {
        YakSwapCell cell =
            new YakSwapCell(vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, YAK_SWAP_ROUTER);

        Hop[] memory hops = new Hop[](1);
        hops[0] = Hop({
            action: Action.HopAndCall,
            requiredGasLimit: 900_000,
            recipientGasLimit: 450_000,
            trade: "",
            bridgePath: BridgePath({
                sourceBridgeIsNative: true,
                bridgeSourceChain: address(nativeTokenHome),
                bridgeDestinationChain: randomRemoteAddress,
                cellDestinationChain: vm.addr(9876),
                destinationBlockchainID: REMOTE_BLOCKCHAIN_ID,
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions = Instructions({
            rollbackTeleporterFee: 0,
            rollbackGasLimit: 450_000,
            receiver: vm.addr(123),
            payableReceiver: true,
            hops: hops,
            sourceId: 1
        });

        CellPayload memory payload = CellPayload({
            tesseractID: "",
            instructions: instructions,
            sourceBlockchainID: "",
            rollbackDestination: address(0)
        });

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveTokens(address(cell), address(wavaxTokenHome), 100e18, payload);
    }

    function test_Native_ERC20_HopAndCall() public {
        YakSwapCell cell =
            new YakSwapCell(vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, YAK_SWAP_ROUTER);

        Hop[] memory hops = new Hop[](1);
        hops[0] = Hop({
            action: Action.HopAndCall,
            requiredGasLimit: 900_000,
            recipientGasLimit: 450_000,
            trade: "",
            bridgePath: BridgePath({
                sourceBridgeIsNative: false,
                bridgeSourceChain: address(wavaxTokenHome),
                bridgeDestinationChain: randomRemoteAddress,
                cellDestinationChain: vm.addr(9876),
                destinationBlockchainID: REMOTE_BLOCKCHAIN_ID,
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions = Instructions({
            rollbackTeleporterFee: 0,
            rollbackGasLimit: 450_000,
            receiver: vm.addr(123),
            payableReceiver: true,
            hops: hops,
            sourceId: 1
        });
        CellPayload memory payload = CellPayload({
            tesseractID: "",
            instructions: instructions,
            sourceBlockchainID: "",
            rollbackDestination: address(0)
        });

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveNative(address(cell), 10e18, payload);
    }

    function test_ERC20_ERC20_SwapAndHop() public {
        YakSwapCell cell =
            new YakSwapCell(vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, YAK_SWAP_ROUTER);

        uint256 amountIn = 1000e6;
        YakSwapCell.Extras memory extras =
            YakSwapCell.Extras({maxSteps: 2, gasPrice: 25e9, slippageBips: 100, yakSwapFeeBips: 0});
        (bytes memory trade, uint256 gasEstimate) = cell.route(amountIn, USDC, WAVAX, abi.encode(extras));
        YakSwapCell.TradeData memory decodedTrade = abi.decode(trade, (YakSwapCell.TradeData));

        vm.assertGt(decodedTrade.trade.amountOut, 0);

        Hop[] memory hops = new Hop[](1);
        hops[0] = Hop({
            action: Action.SwapAndHop,
            requiredGasLimit: gasEstimate + 450_000,
            recipientGasLimit: gasEstimate,
            trade: trade,
            bridgePath: BridgePath({
                sourceBridgeIsNative: false,
                bridgeSourceChain: address(wavaxTokenHome),
                bridgeDestinationChain: randomRemoteAddress,
                cellDestinationChain: vm.addr(9876),
                destinationBlockchainID: REMOTE_BLOCKCHAIN_ID,
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions = Instructions({
            rollbackTeleporterFee: 0,
            rollbackGasLimit: 450_000,
            receiver: vm.addr(123),
            payableReceiver: true,
            hops: hops,
            sourceId: 1
        });

        CellPayload memory payload = CellPayload({
            tesseractID: "",
            instructions: instructions,
            sourceBlockchainID: "",
            rollbackDestination: address(0)
        });

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveTokens(address(cell), address(usdcTokenHome), amountIn, payload);
    }

    function test_ERC20_Native_SwapAndHop() public {
        YakSwapCell cell =
            new YakSwapCell(vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, YAK_SWAP_ROUTER);

        uint256 amountIn = 1000e6;
        YakSwapCell.Extras memory extras =
            YakSwapCell.Extras({maxSteps: 2, gasPrice: 25e9, slippageBips: 100, yakSwapFeeBips: 0});
        (bytes memory trade, uint256 gasEstimate) = cell.route(amountIn, USDC, WAVAX, abi.encode(extras));
        YakSwapCell.TradeData memory decodedTrade = abi.decode(trade, (YakSwapCell.TradeData));

        vm.assertGt(decodedTrade.trade.amountOut, 0);

        Hop[] memory hops = new Hop[](1);
        hops[0] = Hop({
            action: Action.SwapAndHop,
            requiredGasLimit: gasEstimate + 450_000,
            recipientGasLimit: gasEstimate,
            trade: trade,
            bridgePath: BridgePath({
                sourceBridgeIsNative: true,
                bridgeSourceChain: address(nativeTokenHome),
                bridgeDestinationChain: randomRemoteAddress,
                cellDestinationChain: vm.addr(9876),
                destinationBlockchainID: REMOTE_BLOCKCHAIN_ID,
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions = Instructions({
            rollbackTeleporterFee: 0,
            rollbackGasLimit: 450_000,
            receiver: vm.addr(123),
            payableReceiver: true,
            hops: hops,
            sourceId: 1
        });

        CellPayload memory payload = CellPayload({
            tesseractID: "",
            instructions: instructions,
            sourceBlockchainID: "",
            rollbackDestination: address(0)
        });

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveTokens(address(cell), address(usdcTokenHome), amountIn, payload);
    }

    function test_Native_ERC20_SwapAndHop() public {
        YakSwapCell cell =
            new YakSwapCell(vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, YAK_SWAP_ROUTER);

        uint256 amountIn = 10e18;
        YakSwapCell.Extras memory extras =
            YakSwapCell.Extras({maxSteps: 2, gasPrice: 25e9, slippageBips: 100, yakSwapFeeBips: 0});
        (bytes memory trade, uint256 gasEstimate) = cell.route(amountIn, WAVAX, USDC, abi.encode(extras));
        YakSwapCell.TradeData memory decodedTrade = abi.decode(trade, (YakSwapCell.TradeData));

        vm.assertGt(decodedTrade.trade.amountOut, 0);

        Hop[] memory hops = new Hop[](1);
        hops[0] = Hop({
            action: Action.SwapAndHop,
            requiredGasLimit: gasEstimate + 450_000,
            recipientGasLimit: gasEstimate,
            trade: trade,
            bridgePath: BridgePath({
                sourceBridgeIsNative: false,
                bridgeSourceChain: address(usdcTokenHome),
                bridgeDestinationChain: randomRemoteAddress,
                cellDestinationChain: vm.addr(9876),
                destinationBlockchainID: REMOTE_BLOCKCHAIN_ID,
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions = Instructions({
            rollbackTeleporterFee: 0,
            rollbackGasLimit: 450_000,
            receiver: vm.addr(123),
            payableReceiver: true,
            hops: hops,
            sourceId: 1
        });

        CellPayload memory payload = CellPayload({
            tesseractID: "",
            instructions: instructions,
            sourceBlockchainID: "",
            rollbackDestination: address(0)
        });

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveNative(address(cell), amountIn, payload);
    }
}
