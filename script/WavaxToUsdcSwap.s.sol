// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Script.sol";
import "./../src/interfaces/ISwapData.sol";
import "./../src/Initiator.sol";

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
    IYakRouter constant ROUTER = IYakRouter(0x1e6911E7Eec3b35F9Ebf4183EF6bAbF64d859FF5);

    address constant EXECUTOR = 0x5B870cbe9506Db7139B0e7d408280Ba21d9E5B5a;
    address constant INITIATOR = 0xCC6590648FAf66c56a2fF653ce528AC355Bb4ad0;

    uint256 constant SWAP_AMOUNT_IN = 1e16;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        string memory fuji_rpc = vm.envString("FUJI_RPC_URL");

        uint256 tesForkId = vm.activeFork();
        uint256 fujiForkId = vm.createFork(fuji_rpc);
        vm.selectFork(fujiForkId);
        FormattedOffer memory offer = ROUTER.findBestPath(SWAP_AMOUNT_IN, WAVAX_FUJI, USDC_FUJI, 2);
        console.log(offer.amounts[offer.amounts.length - 1]);

        Trade memory trade = Trade({
            amountIn: offer.amounts[0],
            amountOut: (offer.amounts[offer.amounts.length - 1] * 950) / 1000,
            path: offer.path,
            adapters: offer.adapters
        });

        BridgePath[] memory bridgePaths = new BridgePath[](2);
        bridgePaths[0] =
            BridgePath({from: WAVAX_TES_REMOTE, to: WAVAX_HOME_FUJI, destinationBlockchainId: FUJI_BLOCKCHAIN_ID});
        bridgePaths[1] =
            BridgePath({from: USDC_FUJI_HOME, to: USDC_TES_REMOTE, destinationBlockchainId: TES_BLOCKCHAIN_ID});

        SwapData memory swapData = SwapData({
            receiver: vm.addr(privateKey),
            executor: EXECUTOR,
            gasLimit: 2_000_000,
            trade: trade,
            bridgePath: bridgePaths
        });
        //console.log(vm.toString(abi.encodeWithSelector(Initiator.crossChainSwap.selector, swapData)));

        vm.selectFork(tesForkId);
        WarpMessengerMock warp = new WarpMessengerMock();
        vm.etch(0x0200000000000000000000000000000000000005, address(warp).code);

        vm.startBroadcast(privateKey);

        IERC20(WAVAX_TES_REMOTE).approve(INITIATOR, SWAP_AMOUNT_IN);
        Initiator(INITIATOR).crossChainSwap(swapData);

        vm.stopBroadcast();
    }
}

contract WarpMessengerMock {
    function sendWarpMessage(bytes calldata payload) external returns (bytes32 messageID) {}
}

// forge script --chain 732 script/WavaxToUsdcSwap.s.sol:WavaxToUsdcSwap --rpc-url $TESCHAIN_RPC_URL --broadcast --verify -vvvv
