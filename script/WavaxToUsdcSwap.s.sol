// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "./../src/Cell.sol";
import "./../src/YakSwapCell.sol";
import "./../src/interfaces/IYakRouter.sol";

// forge script --chain 732 script/WavaxToUsdcSwap.s.sol:WavaxToUsdcSwap --rpc-url $TESCHAIN_RPC_URL --broadcast --skip-simulation -vvvv

contract WavaxToUsdcSwap is Script {
    bytes32 constant FUJI_BLOCKCHAIN_ID = 0x7fc93d85c6d62c5b2ac0b519c87010ea5294012d1e407030d6acd0021cac10d5;
    bytes32 constant TES_BLOCKCHAIN_ID = 0x6b1e340aeda6d5780cef4e45728665efa61057acc52fb862b75def9190974288;

    address constant WAVAX_FUJI = 0xd00ae08403B9bbb9124bB305C09058E32C39A48c;
    address constant WAVAX_TES_REMOTE = 0x33be589E446709E411684Cb3B25E5CA2Ebedcfc0;
    address constant WAVAX_HOME_FUJI = 0x00aF781618d696412A3B4287a9BaF922acc7DddE;
    address constant USDC_FUJI = 0x5425890298aed601595a70AB815c96711a31Bc65;
    address constant USDC_FUJI_HOME = 0x801B217A93b7E6CC4D390dDFA91391083723F060;
    address constant USDC_TES_REMOTE = 0x6598E8dCA0BCA6AcEB41d4E004e5AaDef9B24293;

    address constant CELL_FUJI = 0xf2F409eE504703F3507006115685D42F2B1e5cE1;
    address constant CELL_TES = 0x72ee02FA4CC61D2752eCfD174C1e113feF789589;

    uint256 constant SWAP_AMOUNT_IN = 1e16;

    uint256 constant HOP_GAS_ESTIMATE = 500_000;
    uint256 constant GAS_BUFFER = 500_000;

    uint256 constant TRADE_SLIPPAGE_BIPS = 500;

    uint256 constant TELEPORTER_FEE_BIPS_ORIGIN = 100;
    uint256 constant TELEPORTER_FEE_BIPS_DESTINATION = 200;
    uint256 constant FEE_BIPS_DIVISOR = 10_000;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        string memory fujiRpc = vm.envString("FUJI_RPC_URL");
        uint256 tesForkId = vm.activeFork();
        uint256 fujiForkId = vm.createFork(fujiRpc);

        vm.selectFork(fujiForkId);

        YakSwapCell.Extras memory extras =
            YakSwapCell.Extras({maxSteps: 2, gasPrice: 25e9, slippageBips: TRADE_SLIPPAGE_BIPS, yakSwapFeeBips: 0});
        (bytes memory trade, uint256 gasEstimate) =
            YakSwapCell(payable(CELL_FUJI)).route(SWAP_AMOUNT_IN, WAVAX_FUJI, USDC_FUJI, abi.encode(extras));

        Trade memory decodedTrade = abi.decode(trade, (Trade));
        console.log("AMOUNT OUT %d", decodedTrade.amountOut);

        vm.selectFork(tesForkId);

        uint256 teleporterFeeOrigin = (SWAP_AMOUNT_IN * TELEPORTER_FEE_BIPS_ORIGIN) / FEE_BIPS_DIVISOR;

        Hop[] memory hops = new Hop[](2);
        hops[0] = Hop({
            action: Action.HopAndCall,
            requiredGasLimit: gasEstimate + GAS_BUFFER + HOP_GAS_ESTIMATE,
            recipientGasLimit: gasEstimate + GAS_BUFFER,
            trade: "",
            bridgePath: BridgePath({
                bridgeSourceChain: WAVAX_TES_REMOTE,
                sourceBridgeIsNative: false,
                bridgeDestinationChain: WAVAX_HOME_FUJI,
                cellDestinationChain: CELL_FUJI,
                destinationBlockchainID: FUJI_BLOCKCHAIN_ID,
                teleporterFee: teleporterFeeOrigin,
                secondaryTeleporterFee: 0
            })
        });
        hops[1] = Hop({
            action: Action.SwapAndHop,
            requiredGasLimit: HOP_GAS_ESTIMATE,
            recipientGasLimit: 0,
            trade: trade,
            bridgePath: BridgePath({
                bridgeSourceChain: USDC_FUJI_HOME,
                sourceBridgeIsNative: false,
                bridgeDestinationChain: USDC_TES_REMOTE,
                cellDestinationChain: address(0),
                destinationBlockchainID: TES_BLOCKCHAIN_ID,
                teleporterFee: (decodedTrade.amountOut * TELEPORTER_FEE_BIPS_DESTINATION) / FEE_BIPS_DIVISOR,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions = Instructions({
            rollbackTeleporterFee: 0,
            rollbackGasLimit: HOP_GAS_ESTIMATE,
            receiver: vm.addr(privateKey),
            payableReceiver: true,
            hops: hops
        });

        //console.log(vm.toString(abi.encodeWithSelector(Initiator.initiate.selector, swapData)));

        WarpMessengerMock warp = new WarpMessengerMock();
        vm.etch(0x0200000000000000000000000000000000000005, address(warp).code);

        vm.startBroadcast(privateKey);

        IERC20(WAVAX_TES_REMOTE).approve(CELL_TES, SWAP_AMOUNT_IN + teleporterFeeOrigin);
        Cell(payable(CELL_TES)).initiate(WAVAX_TES_REMOTE, SWAP_AMOUNT_IN + teleporterFeeOrigin, instructions);

        vm.stopBroadcast();
    }
}

contract WarpMessengerMock {
    function sendWarpMessage(bytes calldata payload) external returns (bytes32 messageID) {}
}

// forge script --chain 732 script/WavaxToUsdcSwap.s.sol:WavaxToUsdcSwap --rpc-url $TESCHAIN_RPC_URL --broadcast --skip-simulation -vvvv
