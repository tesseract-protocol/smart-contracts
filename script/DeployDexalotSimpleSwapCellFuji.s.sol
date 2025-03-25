// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/DexalotSimpleSwapCell.sol";

// source .env && forge script script/DeployDexalotSimpleSwapCellFuji.s.sol:DeployDexalotSimpleSwapCellFuji --rpc-url $FUJI_RPC_URL --broadcast --skip-simulation --verifier-url 'https://api.routescan.io/v2/network/testnet/evm/43113/etherscan' --etherscan-api-key "verifyContract" --verify

contract DeployDexalotSimpleSwapCellFuji is Script {
    // Deploy configuration constants
    address constant MAINNET_RFQ = 0x1f06d7533890dBD67106Fee55FA9693D412e7551; // Replace with actual RFQ address
    uint256 constant SWAP_GAS_ESTIMATE = 125_000; // Approximate gas used for a swap
    address constant WRAPPED_NATIVE_TOKEN = 0xd00ae08403B9bbb9124bB305C09058E32C39A48c; // WAVAX on Avalanche C-Chain
    address public constant TELEPORTER_REGISTRY = 0xF86Cb19Ad8405AEFa7d09C778215D2Cb6eBfB228;
    uint256 public constant MIN_TELEPORTER_VERSION = 1;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        WarpMessengerMock warp = new WarpMessengerMock();
        vm.etch(0x0200000000000000000000000000000000000005, address(warp).code);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy contract
        DexalotSimpleSwapCell cell = new DexalotSimpleSwapCell(
            deployerAddress,
            WRAPPED_NATIVE_TOKEN,
            TELEPORTER_REGISTRY,
            MIN_TELEPORTER_VERSION,
            MAINNET_RFQ,
            SWAP_GAS_ESTIMATE
        );

        vm.stopBroadcast();

        // Log deployment information
        console.log("\nDeployment Summary:");
        console.log("-------------------");
        console.log("Deployer/Owner:", deployerAddress);
        console.log("Contract:", address(cell));
        console.log("MainnetRFQ:", MAINNET_RFQ);
        console.log("SwapGasEstimate:", SWAP_GAS_ESTIMATE);
        console.log("WrappedNativeToken:", WRAPPED_NATIVE_TOKEN);
    }
}

contract WarpMessengerMock {
    function getBlockchainID() external returns (bytes32 blockchainID) {}
}
