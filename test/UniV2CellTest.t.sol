// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseTest} from "./BaseTest.t.sol";
import {UniV2Cell} from "./../src/UniV2Cell.sol";
import {Hop, Action, BridgePath, Instructions, CellPayload, ThirdPartyFee} from "../src/interfaces/ICell.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UniV2CellTest is BaseTest {
    address public UNIV2_FACTORY = 0x9Ad6C38BE94206cA50bb0d90783181662f0Cfa10;

    function test_ERC20_ERC20_SwapAndTransfer() public {
        address[] memory hopTokens = new address[](2);
        hopTokens[0] = WAVAX;
        hopTokens[1] = USDC;
        UniV2Cell cell = new UniV2Cell(
            vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, UNIV2_FACTORY, 3, 120_000, hopTokens, 3
        );

        uint256 amountIn = 100e18;
        UniV2Cell.Extras memory extras = UniV2Cell.Extras({slippageBips: 200});
        (bytes memory trade, uint256 gasEstimate) = cell.route(amountIn, WAVAX, USDC, abi.encode(extras));
        UniV2Cell.Trade memory decodedTrade = abi.decode(trade, (UniV2Cell.Trade));

        vm.assertGt(decodedTrade.amountOut, 0);

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
            rollbackReceiver: vm.addr(123),
            payableReceiver: true,
            rollbackTeleporterFee: 0,
            rollbackGasLimit: 450_000,
            hops: hops,
            sourceId: 1,
            thirdPartyFee: ThirdPartyFee({exemptSingleHop: true, fixedFee: 0, baseFeeBips: 0, feeCollector: address(0)})
        });

        CellPayload memory payload = CellPayload({
            tesseractID: "", instructions: instructions, sourceBlockchainID: "", rollbackDestination: address(0)
        });

        mockReceiveTokens(address(cell), address(wavaxTokenHome), amountIn, payload);

        vm.assertApproxEqRel(IERC20(USDC).balanceOf(vm.addr(123)), decodedTrade.amountOut, 0.1e18);
    }

    function test_ERC20_ERC20_Multi_SwapAndTransfer() public {
        address[] memory hopTokens = new address[](2);
        hopTokens[0] = WAVAX;
        hopTokens[1] = USDC;
        UniV2Cell cell = new UniV2Cell(
            vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, UNIV2_FACTORY, 3, 120_000, hopTokens, 3
        );

        uint256 amountIn = 1000e6;
        UniV2Cell.Extras memory extras = UniV2Cell.Extras({slippageBips: 200});
        (bytes memory trade, uint256 gasEstimate) = cell.route(amountIn, USDC, YAK, abi.encode(extras));
        UniV2Cell.Trade memory decodedTrade = abi.decode(trade, (UniV2Cell.Trade));

        vm.assertGt(decodedTrade.amountOut, 0);

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
            rollbackReceiver: vm.addr(123),
            rollbackTeleporterFee: 0,
            rollbackGasLimit: 450_000,
            hops: hops,
            sourceId: 1,
            thirdPartyFee: ThirdPartyFee({exemptSingleHop: true, fixedFee: 0, baseFeeBips: 0, feeCollector: address(0)})
        });

        CellPayload memory payload = CellPayload({
            tesseractID: "", instructions: instructions, sourceBlockchainID: "", rollbackDestination: address(0)
        });

        mockReceiveTokens(address(cell), address(usdcTokenHome), amountIn, payload);

        vm.assertApproxEqRel(IERC20(YAK).balanceOf(vm.addr(123)), decodedTrade.amountOut, 0.1e18);
    }

    function test_Native_ERC20_SwapAndTransfer() public {
        address[] memory hopTokens = new address[](2);
        hopTokens[0] = WAVAX;
        hopTokens[1] = USDC;
        UniV2Cell cell = new UniV2Cell(
            vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, UNIV2_FACTORY, 3, 120_000, hopTokens, 3
        );

        uint256 amountIn = 10e18;
        UniV2Cell.Extras memory extras = UniV2Cell.Extras({slippageBips: 200});
        (bytes memory trade, uint256 gasEstimate) = cell.route(amountIn, WAVAX, USDC, abi.encode(extras));
        UniV2Cell.Trade memory decodedTrade = abi.decode(trade, (UniV2Cell.Trade));

        vm.assertGt(decodedTrade.amountOut, 0);

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
            rollbackReceiver: vm.addr(123),
            payableReceiver: true,
            hops: hops,
            sourceId: 1,
            thirdPartyFee: ThirdPartyFee({exemptSingleHop: true, fixedFee: 0, baseFeeBips: 0, feeCollector: address(0)})
        });

        CellPayload memory payload = CellPayload({
            tesseractID: "", instructions: instructions, sourceBlockchainID: "", rollbackDestination: address(0)
        });

        mockReceiveNative(address(cell), amountIn, payload);

        vm.assertApproxEqRel(IERC20(USDC).balanceOf(vm.addr(123)), decodedTrade.amountOut, 0.1e18);
    }

    function test_ERC20_Native_SwapAndTransfer() public {
        address[] memory hopTokens = new address[](2);
        hopTokens[0] = WAVAX;
        hopTokens[1] = USDC;
        UniV2Cell cell = new UniV2Cell(
            vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, UNIV2_FACTORY, 3, 120_000, hopTokens, 3
        );

        uint256 amountIn = 1000e6;
        UniV2Cell.Extras memory extras = UniV2Cell.Extras({slippageBips: 200});
        (bytes memory trade, uint256 gasEstimate) = cell.route(amountIn, USDC, WAVAX, abi.encode(extras));
        UniV2Cell.Trade memory decodedTrade = abi.decode(trade, (UniV2Cell.Trade));

        vm.assertGt(decodedTrade.amountOut, 0);

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
            rollbackReceiver: vm.addr(123),
            payableReceiver: true,
            hops: hops,
            sourceId: 1,
            thirdPartyFee: ThirdPartyFee({exemptSingleHop: true, fixedFee: 0, baseFeeBips: 0, feeCollector: address(0)})
        });

        CellPayload memory payload = CellPayload({
            tesseractID: "", instructions: instructions, sourceBlockchainID: "", rollbackDestination: address(0)
        });

        mockReceiveTokens(address(cell), address(usdcTokenHome), amountIn, payload);

        vm.assertApproxEqRel(address(vm.addr(123)).balance, decodedTrade.amountOut, 0.1e18);
    }

    function test_ERC20_ERC20_Hop() public {
        address[] memory hopTokens = new address[](2);
        hopTokens[0] = WAVAX;
        hopTokens[1] = USDC;
        UniV2Cell cell = new UniV2Cell(
            vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, UNIV2_FACTORY, 3, 120_000, hopTokens, 3
        );

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
            rollbackReceiver: vm.addr(123),
            payableReceiver: true,
            hops: hops,
            sourceId: 1,
            thirdPartyFee: ThirdPartyFee({exemptSingleHop: true, fixedFee: 0, baseFeeBips: 0, feeCollector: address(0)})
        });

        CellPayload memory payload = CellPayload({
            tesseractID: "", instructions: instructions, sourceBlockchainID: "", rollbackDestination: address(0)
        });

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveTokens(address(cell), address(usdcTokenHome), 1000e6, payload);
    }

    function test_ERC20_Native_Hop() public {
        address[] memory hopTokens = new address[](2);
        hopTokens[0] = WAVAX;
        hopTokens[1] = USDC;
        UniV2Cell cell = new UniV2Cell(
            vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, UNIV2_FACTORY, 3, 120_000, hopTokens, 3
        );

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
            rollbackReceiver: vm.addr(123),
            payableReceiver: true,
            hops: hops,
            sourceId: 1,
            thirdPartyFee: ThirdPartyFee({exemptSingleHop: true, fixedFee: 0, baseFeeBips: 0, feeCollector: address(0)})
        });

        CellPayload memory payload = CellPayload({
            tesseractID: "", instructions: instructions, sourceBlockchainID: "", rollbackDestination: address(0)
        });

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveTokens(address(cell), address(wavaxTokenHome), 10e18, payload);
    }

    function test_Native_ERC20_Hop() public {
        address[] memory hopTokens = new address[](2);
        hopTokens[0] = WAVAX;
        hopTokens[1] = USDC;
        UniV2Cell cell = new UniV2Cell(
            vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, UNIV2_FACTORY, 3, 120_000, hopTokens, 3
        );

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
            rollbackReceiver: vm.addr(123),
            payableReceiver: true,
            hops: hops,
            sourceId: 1,
            thirdPartyFee: ThirdPartyFee({exemptSingleHop: true, fixedFee: 0, baseFeeBips: 0, feeCollector: address(0)})
        });

        CellPayload memory payload = CellPayload({
            tesseractID: "", instructions: instructions, sourceBlockchainID: "", rollbackDestination: address(0)
        });

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveNative(address(cell), 10e18, payload);
    }

    function test_ERC20_ERC20_HopAndCall() public {
        address[] memory hopTokens = new address[](2);
        hopTokens[0] = WAVAX;
        hopTokens[1] = USDC;
        UniV2Cell cell = new UniV2Cell(
            vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, UNIV2_FACTORY, 3, 120_000, hopTokens, 3
        );

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
            rollbackReceiver: vm.addr(123),
            payableReceiver: true,
            hops: hops,
            sourceId: 1,
            thirdPartyFee: ThirdPartyFee({exemptSingleHop: true, fixedFee: 0, baseFeeBips: 0, feeCollector: address(0)})
        });

        CellPayload memory payload = CellPayload({
            tesseractID: "", instructions: instructions, sourceBlockchainID: "", rollbackDestination: address(0)
        });

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveTokens(address(cell), address(wavaxTokenHome), 100e18, payload);
    }

    function test_ERC20_Native_HopAndCall() public {
        address[] memory hopTokens = new address[](2);
        hopTokens[0] = WAVAX;
        hopTokens[1] = USDC;
        UniV2Cell cell = new UniV2Cell(
            vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, UNIV2_FACTORY, 3, 120_000, hopTokens, 3
        );

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
            rollbackReceiver: vm.addr(123),
            payableReceiver: true,
            hops: hops,
            sourceId: 1,
            thirdPartyFee: ThirdPartyFee({exemptSingleHop: true, fixedFee: 0, baseFeeBips: 0, feeCollector: address(0)})
        });

        CellPayload memory payload = CellPayload({
            tesseractID: "", instructions: instructions, sourceBlockchainID: "", rollbackDestination: address(0)
        });

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveTokens(address(cell), address(wavaxTokenHome), 100e18, payload);
    }

    function test_Native_ERC20_HopAndCall() public {
        address[] memory hopTokens = new address[](2);
        hopTokens[0] = WAVAX;
        hopTokens[1] = USDC;
        UniV2Cell cell = new UniV2Cell(
            vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, UNIV2_FACTORY, 3, 120_000, hopTokens, 3
        );

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
            rollbackReceiver: vm.addr(123),
            payableReceiver: true,
            hops: hops,
            sourceId: 1,
            thirdPartyFee: ThirdPartyFee({exemptSingleHop: true, fixedFee: 0, baseFeeBips: 0, feeCollector: address(0)})
        });
        CellPayload memory payload = CellPayload({
            tesseractID: "", instructions: instructions, sourceBlockchainID: "", rollbackDestination: address(0)
        });

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveNative(address(cell), 10e18, payload);
    }

    function test_ERC20_ERC20_SwapAndHop() public {
        address[] memory hopTokens = new address[](2);
        hopTokens[0] = WAVAX;
        hopTokens[1] = USDC;
        UniV2Cell cell = new UniV2Cell(
            vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, UNIV2_FACTORY, 3, 120_000, hopTokens, 3
        );

        uint256 amountIn = 1000e6;
        UniV2Cell.Extras memory extras = UniV2Cell.Extras({slippageBips: 200});
        (bytes memory trade, uint256 gasEstimate) = cell.route(amountIn, USDC, WAVAX, abi.encode(extras));
        UniV2Cell.Trade memory decodedTrade = abi.decode(trade, (UniV2Cell.Trade));

        vm.assertGt(decodedTrade.amountOut, 0);

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
            rollbackReceiver: vm.addr(123),
            payableReceiver: true,
            hops: hops,
            sourceId: 1,
            thirdPartyFee: ThirdPartyFee({exemptSingleHop: true, fixedFee: 0, baseFeeBips: 0, feeCollector: address(0)})
        });

        CellPayload memory payload = CellPayload({
            tesseractID: "", instructions: instructions, sourceBlockchainID: "", rollbackDestination: address(0)
        });

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveTokens(address(cell), address(usdcTokenHome), amountIn, payload);
    }

    function test_ERC20_Native_SwapAndHop() public {
        address[] memory hopTokens = new address[](2);
        hopTokens[0] = WAVAX;
        hopTokens[1] = USDC;
        UniV2Cell cell = new UniV2Cell(
            vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, UNIV2_FACTORY, 3, 120_000, hopTokens, 3
        );

        uint256 amountIn = 1000e6;
        UniV2Cell.Extras memory extras = UniV2Cell.Extras({slippageBips: 200});
        (bytes memory trade, uint256 gasEstimate) = cell.route(amountIn, USDC, WAVAX, abi.encode(extras));
        UniV2Cell.Trade memory decodedTrade = abi.decode(trade, (UniV2Cell.Trade));

        vm.assertGt(decodedTrade.amountOut, 0);

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
            rollbackReceiver: vm.addr(123),
            payableReceiver: true,
            hops: hops,
            sourceId: 1,
            thirdPartyFee: ThirdPartyFee({exemptSingleHop: true, fixedFee: 0, baseFeeBips: 0, feeCollector: address(0)})
        });

        CellPayload memory payload = CellPayload({
            tesseractID: "", instructions: instructions, sourceBlockchainID: "", rollbackDestination: address(0)
        });

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveTokens(address(cell), address(usdcTokenHome), amountIn, payload);
    }

    function test_Native_ERC20_SwapAndHop() public {
        address[] memory hopTokens = new address[](2);
        hopTokens[0] = WAVAX;
        hopTokens[1] = USDC;
        UniV2Cell cell = new UniV2Cell(
            vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, UNIV2_FACTORY, 3, 120_000, hopTokens, 3
        );

        uint256 amountIn = 10e18;
        UniV2Cell.Extras memory extras = UniV2Cell.Extras({slippageBips: 200});
        (bytes memory trade, uint256 gasEstimate) = cell.route(amountIn, WAVAX, USDC, abi.encode(extras));
        UniV2Cell.Trade memory decodedTrade = abi.decode(trade, (UniV2Cell.Trade));

        vm.assertGt(decodedTrade.amountOut, 0);

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
            rollbackReceiver: vm.addr(123),
            payableReceiver: true,
            hops: hops,
            sourceId: 1,
            thirdPartyFee: ThirdPartyFee({exemptSingleHop: true, fixedFee: 0, baseFeeBips: 0, feeCollector: address(0)})
        });

        CellPayload memory payload = CellPayload({
            tesseractID: "", instructions: instructions, sourceBlockchainID: "", rollbackDestination: address(0)
        });

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveNative(address(cell), amountIn, payload);
    }
}
