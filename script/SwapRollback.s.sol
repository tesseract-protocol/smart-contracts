// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Script.sol";
import "./../src/Cell.sol";
import "./../src/interfaces/IYakRouter.sol";

// forge script --chain 732 script/SwapRollback.s.sol:SwapRollback --rpc-url $TESCHAIN_RPC_URL --broadcast --skip-simulation -vvvv

contract SwapRollback is Script {
    bytes32 constant FUJI_BLOCKCHAIN_ID = 0x7fc93d85c6d62c5b2ac0b519c87010ea5294012d1e407030d6acd0021cac10d5;
    bytes32 constant TES_BLOCKCHAIN_ID = 0x6b1e340aeda6d5780cef4e45728665efa61057acc52fb862b75def9190974288;

    address constant WAVAX_FUJI = 0xd00ae08403B9bbb9124bB305C09058E32C39A48c;
    address constant WAVAX_TES_REMOTE = 0x33be589E446709E411684Cb3B25E5CA2Ebedcfc0;
    address constant WAVAX_HOME_FUJI = 0x00aF781618d696412A3B4287a9BaF922acc7DddE;
    address constant USDC_FUJI = 0x5425890298aed601595a70AB815c96711a31Bc65;
    address constant USDC_FUJI_HOME = 0x801B217A93b7E6CC4D390dDFA91391083723F060;
    address constant USDC_TES_REMOTE = 0x6598E8dCA0BCA6AcEB41d4E004e5AaDef9B24293;
    IYakRouter constant ROUTER = IYakRouter(0x1e6911E7Eec3b35F9Ebf4183EF6bAbF64d859FF5);

    address payable constant CELL_DESTINATION_CHAIN = payable(0x357894f83b54EdC0e03F342e0164FcD2Bee78E32);
    address payable constant CELL_SOURCE_CHAIN = payable(0x09f6f221A52d55009e8F843446D466261517Cbf7);

    uint256 constant SWAP_AMOUNT_IN = 1e16;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        WarpMessengerMock warp = new WarpMessengerMock();
        vm.etch(0x0200000000000000000000000000000000000005, address(warp).code);

        Trade memory trade = Trade({amountIn: 0, amountOut: 1e18, path: new address[](0), adapters: new address[](0)});

        Hop[] memory hops = new Hop[](2);
        hops[0] = Hop({
            action: Action.HopAndCall,
            requiredGasLimit: 2_850_000,
            recipientGasLimit: 2_500_000,
            trade: "",
            bridgePath: BridgePath({
                bridgeSourceChain: WAVAX_TES_REMOTE,
                destinationBridgeIsNative: false,
                bridgeDestinationChain: WAVAX_HOME_FUJI,
                cellDestinationChain: CELL_DESTINATION_CHAIN,
                destinationBlockchainID: FUJI_BLOCKCHAIN_ID,
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });
        hops[1] = Hop({
            action: Action.SwapAndHop,
            requiredGasLimit: 0,
            recipientGasLimit: 0,
            trade: abi.encode(trade),
            bridgePath: BridgePath({
                bridgeSourceChain: USDC_FUJI_HOME,
                destinationBridgeIsNative: false,
                bridgeDestinationChain: USDC_TES_REMOTE,
                cellDestinationChain: address(0),
                destinationBlockchainID: TES_BLOCKCHAIN_ID,
                teleporterFee: 0,
                secondaryTeleporterFee: 0
            })
        });

        Instructions memory instructions = Instructions({
            sourceBlockchainId: TES_BLOCKCHAIN_ID,
            rollbackTeleporterFee: 0,
            rollbackGasLimit: 350_000,
            receiver: vm.addr(privateKey),
            payableReceiver: true,
            hops: hops
        });

        vm.startBroadcast(privateKey);

        IERC20(WAVAX_TES_REMOTE).approve(CELL_SOURCE_CHAIN, SWAP_AMOUNT_IN);
        Cell(CELL_SOURCE_CHAIN).initiate(WAVAX_TES_REMOTE, SWAP_AMOUNT_IN, instructions);

        vm.stopBroadcast();
    }
}

contract WarpMessengerMock {
    function sendWarpMessage(bytes calldata payload) external returns (bytes32 messageID) {}
}
