// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./BaseTest.t.sol";
import "./../src/interfaces/ICell.sol";
import "./../src/HopOnlyCell.sol";

contract HopOnlyCellTest is BaseTest {
    function test_SwapAndTransfer() public {
        HopOnlyCell cell = new HopOnlyCell();

        Hop[] memory hops = new Hop[](2);
        hops[1] = Hop({
            action: Action.SwapAndTransfer,
            gasLimit: 0,
            trade: "",
            bridgePath: BridgePath({
                multihop: false,
                bridgeSourceChain: address(0),
                bridgeDestinationChain: address(0),
                cellDestinationChain: address(0),
                destinationBlockchainId: "",
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions =
            Instructions({sourceBlockchainId: "", rollbackTeleporterFee: 0, receiver: vm.addr(123), hops: hops});

        CellPayload memory payload = CellPayload({instructions: instructions, hop: 0});

        mockReceiveTokens(address(cell), 1000e6, payload);

        vm.assertEq(IERC20(USDC).balanceOf(vm.addr(123)), 1000e6);
    }

    function test_Hop() public {
        HopOnlyCell cell = new HopOnlyCell();

        Hop[] memory hops = new Hop[](2);
        hops[1] = Hop({
            action: Action.Hop,
            gasLimit: 450_000,
            trade: "",
            bridgePath: BridgePath({
                multihop: false,
                bridgeSourceChain: address(usdcTokenHome),
                bridgeDestinationChain: randomRemoteAddress,
                cellDestinationChain: vm.addr(9876),
                destinationBlockchainId: REMOTE_BLOCKCHAIN_ID,
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions =
            Instructions({sourceBlockchainId: "", rollbackTeleporterFee: 0, receiver: vm.addr(123), hops: hops});

        CellPayload memory payload = CellPayload({instructions: instructions, hop: 0});

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveTokens(address(cell), 1000e6, payload);
    }

    function test_HopAndCall() public {
        HopOnlyCell cell = new HopOnlyCell();

        Hop[] memory hops = new Hop[](2);
        hops[1] = Hop({
            action: Action.HopAndCall,
            gasLimit: 450_000,
            trade: "",
            bridgePath: BridgePath({
                multihop: false,
                bridgeSourceChain: address(usdcTokenHome),
                bridgeDestinationChain: randomRemoteAddress,
                cellDestinationChain: vm.addr(9876),
                destinationBlockchainId: REMOTE_BLOCKCHAIN_ID,
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions =
            Instructions({sourceBlockchainId: "", rollbackTeleporterFee: 0, receiver: vm.addr(123), hops: hops});

        CellPayload memory payload = CellPayload({instructions: instructions, hop: 0});

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveTokens(address(cell), 1000e6, payload);
    }

    function test_SwapAndHop() public {
        HopOnlyCell cell = new HopOnlyCell();

        Hop[] memory hops = new Hop[](2);
        hops[1] = Hop({
            action: Action.SwapAndHop,
            gasLimit: 450_000,
            trade: "",
            bridgePath: BridgePath({
                multihop: false,
                bridgeSourceChain: address(usdcTokenHome),
                bridgeDestinationChain: randomRemoteAddress,
                cellDestinationChain: vm.addr(9876),
                destinationBlockchainId: REMOTE_BLOCKCHAIN_ID,
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions =
            Instructions({sourceBlockchainId: "", rollbackTeleporterFee: 0, receiver: vm.addr(123), hops: hops});

        CellPayload memory payload = CellPayload({instructions: instructions, hop: 0});

        vm.expectEmit(teleporterRegistry.getLatestTeleporter());
        emit SendCrossChainMessage();
        mockReceiveTokens(address(cell), 1000e6, payload);
    }
}
