// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./BaseTest.t.sol";
import "./../src/interfaces/ICell.sol";
import "./../src/HopOnlyCell.sol";

contract HopOnlyCellTest is BaseTest {
    function test_ERC20_SwapAndTransfer() public {
        HopOnlyCell cell = new HopOnlyCell(WAVAX);

        Hop[] memory hops = new Hop[](2);
        hops[1] = Hop({
            action: Action.SwapAndTransfer,
            requiredGasLimit: 450_000,
            recipientGasLimit: 0,
            trade: "",
            bridgePath: BridgePath({
                multihop: false,
                sourceBridgeIsNative: false,
                bridgeSourceChain: address(0),
                destinationBridgeIsNative: false,
                bridgeDestinationChain: address(0),
                cellDestinationChain: address(0),
                destinationBlockchainId: "",
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions = Instructions({
            sourceBlockchainId: "",
            rollbackTeleporterFee: 0,
            rollbackGasLimit: 450_000,
            receiver: vm.addr(123),
            payableReceiver: true,
            hops: hops
        });

        CellPayload memory payload = CellPayload({instructions: instructions, hop: 0});

        mockReceiveTokens(address(cell), address(usdcTokenHome), 1000e6, payload);

        vm.assertEq(IERC20(USDC).balanceOf(vm.addr(123)), 1000e6);
    }

    function test_Native_SwapAndTransfer() public {
        HopOnlyCell cell = new HopOnlyCell(WAVAX);

        Hop[] memory hops = new Hop[](2);
        hops[1] = Hop({
            action: Action.SwapAndTransfer,
            gasLimit: 0,
            trade: "",
            bridgePath: BridgePath({
                multihop: false,
                sourceBridgeIsNative: false,
                bridgeSourceChain: address(0),
                destinationBridgeIsNative: false,
                bridgeDestinationChain: address(0),
                cellDestinationChain: address(0),
                destinationBlockchainId: "",
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions = Instructions({
            sourceBlockchainId: "",
            rollbackTeleporterFee: 0,
            receiver: vm.addr(123),
            payableReceiver: true,
            hops: hops
        });

        CellPayload memory payload = CellPayload({instructions: instructions, hop: 0});

        mockReceiveNative(address(cell), 100e18, payload);

        vm.assertEq(payable(vm.addr(123)).balance, 100e18);
    }

    function test_ERC20_Hop() public {
        HopOnlyCell cell = new HopOnlyCell(WAVAX);

        Hop[] memory hops = new Hop[](2);
        hops[1] = Hop({
            action: Action.Hop,
            requiredGasLimit: 450_000,
            recipientGasLimit: 0,
            trade: "",
            bridgePath: BridgePath({
                multihop: false,
                sourceBridgeIsNative: false,
                bridgeSourceChain: address(usdcTokenHome),
                destinationBridgeIsNative: false,
                bridgeDestinationChain: randomRemoteAddress,
                cellDestinationChain: vm.addr(9876),
                destinationBlockchainId: REMOTE_BLOCKCHAIN_ID,
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions = Instructions({
            sourceBlockchainId: "",
            rollbackTeleporterFee: 0,
            rollbackGasLimit: 450_000,
            receiver: vm.addr(123),
            payableReceiver: true,
            hops: hops
        });

        CellPayload memory payload = CellPayload({instructions: instructions, hop: 0});

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveTokens(address(cell), address(usdcTokenHome), 1000e6, payload);
    }

    function test_Native_Hop() public {
        HopOnlyCell cell = new HopOnlyCell(WAVAX);

        Hop[] memory hops = new Hop[](2);
        hops[1] = Hop({
            action: Action.Hop,
            gasLimit: 450_000,
            trade: "",
            bridgePath: BridgePath({
                multihop: false,
                sourceBridgeIsNative: true,
                bridgeSourceChain: address(nativeTokenHome),
                destinationBridgeIsNative: false,
                bridgeDestinationChain: randomRemoteAddress,
                cellDestinationChain: vm.addr(9876),
                destinationBlockchainId: REMOTE_BLOCKCHAIN_ID,
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions = Instructions({
            sourceBlockchainId: "",
            rollbackTeleporterFee: 0,
            receiver: vm.addr(123),
            payableReceiver: true,
            hops: hops
        });

        CellPayload memory payload = CellPayload({instructions: instructions, hop: 0});

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveNative(address(cell), 100e18, payload);
    }

    function test_ERC20_HopAndCall() public {
        HopOnlyCell cell = new HopOnlyCell(WAVAX);

        Hop[] memory hops = new Hop[](2);
        hops[1] = Hop({
            action: Action.HopAndCall,
            requiredGasLimit: 450_000,
            recipientGasLimit: 0,
            trade: "",
            bridgePath: BridgePath({
                multihop: false,
                sourceBridgeIsNative: false,
                bridgeSourceChain: address(usdcTokenHome),
                destinationBridgeIsNative: false,
                bridgeDestinationChain: randomRemoteAddress,
                cellDestinationChain: vm.addr(9876),
                destinationBlockchainId: REMOTE_BLOCKCHAIN_ID,
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions = Instructions({
            sourceBlockchainId: "",
            rollbackTeleporterFee: 0,
            rollbackGasLimit: 450_000,
            receiver: vm.addr(123),
            payableReceiver: true,
            hops: hops
        });

        CellPayload memory payload = CellPayload({instructions: instructions, hop: 0});

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveTokens(address(cell), address(usdcTokenHome), 1000e6, payload);
    }

    function test_Native_HopAndCall() public {
        HopOnlyCell cell = new HopOnlyCell(WAVAX);

        Hop[] memory hops = new Hop[](2);
        hops[1] = Hop({
            action: Action.HopAndCall,
            gasLimit: 450_000,
            trade: "",
            bridgePath: BridgePath({
                multihop: false,
                sourceBridgeIsNative: true,
                bridgeSourceChain: address(nativeTokenHome),
                destinationBridgeIsNative: false,
                bridgeDestinationChain: randomRemoteAddress,
                cellDestinationChain: vm.addr(9876),
                destinationBlockchainId: REMOTE_BLOCKCHAIN_ID,
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions = Instructions({
            sourceBlockchainId: "",
            rollbackTeleporterFee: 0,
            receiver: vm.addr(123),
            payableReceiver: true,
            hops: hops
        });

        CellPayload memory payload = CellPayload({instructions: instructions, hop: 0});

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveNative(address(cell), 100e18, payload);
    }

    function test_ERC20_SwapAndHop() public {
        HopOnlyCell cell = new HopOnlyCell(WAVAX);

        Hop[] memory hops = new Hop[](2);
        hops[1] = Hop({
            action: Action.SwapAndHop,
            requiredGasLimit: 450_000,
            recipientGasLimit: 0,
            trade: "",
            bridgePath: BridgePath({
                multihop: false,
                sourceBridgeIsNative: false,
                bridgeSourceChain: address(usdcTokenHome),
                destinationBridgeIsNative: false,
                bridgeDestinationChain: randomRemoteAddress,
                cellDestinationChain: vm.addr(9876),
                destinationBlockchainId: REMOTE_BLOCKCHAIN_ID,
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions = Instructions({
            sourceBlockchainId: "",
            rollbackTeleporterFee: 0,
            rollbackGasLimit: 450_000,
            receiver: vm.addr(123),
            payableReceiver: true,
            hops: hops
        });

        CellPayload memory payload = CellPayload({instructions: instructions, hop: 0});

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveTokens(address(cell), address(usdcTokenHome), 1000e6, payload);
    }

    function test_Native_SwapAndHop() public {
        HopOnlyCell cell = new HopOnlyCell(WAVAX);

        Hop[] memory hops = new Hop[](2);
        hops[1] = Hop({
            action: Action.SwapAndHop,
            gasLimit: 450_000,
            trade: "",
            bridgePath: BridgePath({
                multihop: false,
                sourceBridgeIsNative: true,
                bridgeSourceChain: address(nativeTokenHome),
                destinationBridgeIsNative: false,
                bridgeDestinationChain: randomRemoteAddress,
                cellDestinationChain: vm.addr(9876),
                destinationBlockchainId: REMOTE_BLOCKCHAIN_ID,
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions = Instructions({
            sourceBlockchainId: "",
            rollbackTeleporterFee: 0,
            receiver: vm.addr(123),
            payableReceiver: true,
            hops: hops
        });

        CellPayload memory payload = CellPayload({instructions: instructions, hop: 0});

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveNative(address(cell), 100e18, payload);
    }
}
