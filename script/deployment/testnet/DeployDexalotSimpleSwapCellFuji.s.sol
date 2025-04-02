// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {TeleporterScriptBase} from "../../TeleporterScriptBase.sol";
import {DexalotSimpleSwapCell} from "./../../../src/DexalotSimpleSwapCell.sol";

// forge script script/deployment/testnet/DeployDexalotSimpleSwapCellFuji.s.sol:DeployDexalotSimpleSwapCellFuji --account deployer_fuji --rpc-url $FUJI_RPC_URL --broadcast --skip-simulation --verifier-url 'https://api.routescan.io/v2/network/testnet/evm/43113/etherscan' --etherscan-api-key "verifyContract" --verify

contract DeployDexalotSimpleSwapCellFuji is TeleporterScriptBase {
    address constant MAINNET_RFQ = 0x1f06d7533890dBD67106Fee55FA9693D412e7551;
    uint256 constant SWAP_GAS_ESTIMATE = 125_000;
    address constant WRAPPED_NATIVE_TOKEN = 0xd00ae08403B9bbb9124bB305C09058E32C39A48c;
    address public constant TELEPORTER_REGISTRY = 0xF86Cb19Ad8405AEFa7d09C778215D2Cb6eBfB228;
    uint256 public constant MIN_TELEPORTER_VERSION = 1;

    function run() external {
        address owner = vm.envAddress("CELL_OWNER_TESTNET");

        vm.startBroadcast();

        new DexalotSimpleSwapCell(
            owner, WRAPPED_NATIVE_TOKEN, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, MAINNET_RFQ, SWAP_GAS_ESTIMATE
        );

        vm.stopBroadcast();
    }
}
