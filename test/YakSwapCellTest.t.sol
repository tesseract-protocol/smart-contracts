// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./BaseTest.t.sol";
import "./../src/YakSwapCell.sol";

contract YakSwapCellTest is BaseTest {
    address public YAK_SWAP_ROUTER = 0xC4729E56b831d74bBc18797e0e17A295fA77488c;

    function test_SwapAndTransfer() public {
        YakSwapCell cell = new YakSwapCell(YAK_SWAP_ROUTER);

        uint256 amountIn = 1000e6;
        YakSwapCell.Extras memory extras = YakSwapCell.Extras({maxSteps: 2, gasPrice: 25e9, slippageBips: 100});
        (bytes memory trade, uint256 gasEstimate) = cell.route(amountIn, USDC, WAVAX, abi.encode(extras));
        Trade memory decodedTrade = abi.decode(trade, (Trade));

        vm.assertGt(decodedTrade.amountOut, 0);

        Hop[] memory hops = new Hop[](2);
        hops[1] = Hop({
            action: Action.SwapAndTransfer,
            gasLimit: 450_000 + gasEstimate,
            trade: trade,
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

        mockReceiveTokens(address(cell), amountIn, payload);

        vm.assertApproxEqRel(IERC20(WAVAX).balanceOf(vm.addr(123)), decodedTrade.amountOut, 0.1e18);
    }

    function test_Hop() public {
        YakSwapCell cell = new YakSwapCell(YAK_SWAP_ROUTER);

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
        YakSwapCell cell = new YakSwapCell(YAK_SWAP_ROUTER);

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
        YakSwapCell cell = new YakSwapCell(YAK_SWAP_ROUTER);

        uint256 amountIn = 1000e6;
        YakSwapCell.Extras memory extras = YakSwapCell.Extras({maxSteps: 2, gasPrice: 25e9, slippageBips: 100});
        (bytes memory trade, uint256 gasEstimate) = cell.route(amountIn, USDC, WAVAX, abi.encode(extras));
        Trade memory decodedTrade = abi.decode(trade, (Trade));

        vm.assertGt(decodedTrade.amountOut, 0);

        Hop[] memory hops = new Hop[](2);
        hops[1] = Hop({
            action: Action.SwapAndHop,
            gasLimit: 450_000 + gasEstimate,
            trade: trade,
            bridgePath: BridgePath({
                multihop: false,
                bridgeSourceChain: address(wavaxTokenHome),
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
