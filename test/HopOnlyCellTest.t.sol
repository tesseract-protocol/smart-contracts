// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseTest} from "./BaseTest.t.sol";
import {HopOnlyCell} from "./../src/HopOnlyCell.sol";
import {Hop, Action, BridgePath, Instructions, CellPayload, ThirdPartyFee} from "../src/interfaces/ICell.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract HopOnlyCellTest is BaseTest {
    function test_ERC20_SwapAndTransfer() public {
        HopOnlyCell cell = new HopOnlyCell(vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION);

        Hop[] memory hops = new Hop[](1);
        hops[0] = Hop({
            action: Action.SwapAndTransfer,
            requiredGasLimit: 900_000,
            recipientGasLimit: 450_000,
            trade: "",
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

        mockReceiveTokens(address(cell), address(usdcTokenHome), 1000e6, payload);

        vm.assertEq(ERC20(USDC).balanceOf(vm.addr(123)), 1000e6);
    }

    function test_Native_SwapAndTransfer() public {
        HopOnlyCell cell = new HopOnlyCell(vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION);

        Hop[] memory hops = new Hop[](1);
        hops[0] = Hop({
            action: Action.SwapAndTransfer,
            requiredGasLimit: 900_000,
            recipientGasLimit: 450_000,
            trade: "",
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

        mockReceiveNative(address(cell), 100e18, payload);

        vm.assertEq(payable(vm.addr(123)).balance, 100e18);
    }

    function test_ERC20_Hop() public {
        HopOnlyCell cell = new HopOnlyCell(vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION);

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
                teleporterFee: 1e6,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions = Instructions({
            rollbackTeleporterFee: 0,
            rollbackGasLimit: 450_000,
            receiver: vm.addr(123),
            payableReceiver: true,
            hops: hops,
            sourceId: 1,
            rollbackReceiver: vm.addr(123),
            thirdPartyFee: ThirdPartyFee({exemptSingleHop: true, fixedFee: 0, baseFeeBips: 0, feeCollector: address(0)})
        });

        CellPayload memory payload = CellPayload({
            tesseractID: "", instructions: instructions, sourceBlockchainID: "", rollbackDestination: address(0)
        });

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveTokens(address(cell), address(usdcTokenHome), 1000e6, payload);
    }

    function test_Native_Hop() public {
        HopOnlyCell cell = new HopOnlyCell(vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION);

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
                teleporterFee: 1e18,
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
        mockReceiveNative(address(cell), 100e18, payload);
    }

    function test_ERC20_HopAndCall() public {
        HopOnlyCell cell = new HopOnlyCell(vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION);

        Hop[] memory hops = new Hop[](1);
        hops[0] = Hop({
            action: Action.HopAndCall,
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

    function test_Native_HopAndCall() public {
        HopOnlyCell cell = new HopOnlyCell(vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION);

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
        mockReceiveNative(address(cell), 100e18, payload);
    }

    function test_ERC20_SwapAndHop() public {
        HopOnlyCell cell = new HopOnlyCell(vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION);

        Hop[] memory hops = new Hop[](1);
        hops[0] = Hop({
            action: Action.SwapAndHop,
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

    function test_Native_SwapAndHop() public {
        HopOnlyCell cell = new HopOnlyCell(vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION);

        Hop[] memory hops = new Hop[](1);
        hops[0] = Hop({
            action: Action.SwapAndHop,
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
        mockReceiveNative(address(cell), 100e18, payload);
    }

    function test_InvalidInstructions() public {
        HopOnlyCell cell = new HopOnlyCell(vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION);

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

        writeTokenBalance(address(cell), WAVAX, 100e18);

        vm.assertEq(ERC20(WAVAX).balanceOf(address(cell)), 100e18);
        mockReceiveTokens(address(cell), address(usdcTokenHome), 1e6, payload);
        vm.assertEq(ERC20(WAVAX).balanceOf(address(cell)), 100e18);
    }

    function test_Native_Initiate() public {
        HopOnlyCell cell = new HopOnlyCell(vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION);

        vm.startPrank(vm.addr(1));
        cell.updateFixedFee(1e18);
        vm.stopPrank();

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

        vm.deal(vm.addr(123123), 100e18);
        vm.startPrank(vm.addr(123123));
        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        cell.initiate{value: 10 ether}(address(0), 0, instructions);
        vm.assertEq(address(vm.addr(1)).balance, 0);
    }

    function test_ERC20_Initiate() public {
        HopOnlyCell cell = new HopOnlyCell(vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION);

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

        writeTokenBalance(vm.addr(123123), USDC, 1000e6);
        vm.startPrank(vm.addr(123123));
        ERC20(USDC).approve(address(cell), 1000e6);
        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        cell.initiate(USDC, 1000e6, instructions);
    }

    function test_ERC20_InitiateWithFees() public {
        HopOnlyCell cell = new HopOnlyCell(vm.addr(1), WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION);

        address feeCollector = vm.addr(345);

        vm.startPrank(vm.addr(1));
        cell.updateFixedFee(2e17);
        cell.updateBaseFeeBips(100);
        cell.updateFeeCollector(feeCollector);
        vm.stopPrank();

        Hop[] memory hops = new Hop[](1);
        hops[0] = Hop({
            action: Action.HopAndCall,
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

        address thirdPartyFeeCollector = vm.addr(567);

        Instructions memory instructions = Instructions({
            rollbackTeleporterFee: 0,
            rollbackGasLimit: 450_000,
            receiver: vm.addr(123),
            rollbackReceiver: vm.addr(123),
            payableReceiver: true,
            hops: hops,
            sourceId: 1,
            thirdPartyFee: ThirdPartyFee({
                exemptSingleHop: true, fixedFee: 1e17, baseFeeBips: 100, feeCollector: thirdPartyFeeCollector
            })
        });

        writeTokenBalance(vm.addr(123123), USDC, 1000e6);
        vm.deal(vm.addr(123123), 2e18);
        vm.startPrank(vm.addr(123123));
        ERC20(USDC).approve(address(cell), 1000e6);
        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        cell.initiate{value: 0.3 ether}(USDC, 1000e6, instructions);
        vm.assertEq(address(feeCollector).balance, 2e17);
        vm.assertEq(address(thirdPartyFeeCollector).balance, 1e17);
        vm.assertEq(ERC20(USDC).balanceOf(feeCollector), Math.mulDiv(1000e6, 100, 10_000, Math.Rounding.Up));
        vm.assertEq(ERC20(USDC).balanceOf(thirdPartyFeeCollector), Math.mulDiv(1000e6, 100, 10_000, Math.Rounding.Up));
    }
}
