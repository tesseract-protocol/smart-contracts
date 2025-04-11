// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {TeleporterScriptBase} from "../../TeleporterScriptBase.sol";
import {DexalotSimpleSwapCell} from "./../../../src/DexalotSimpleSwapCell.sol";

// forge script script/deployment/mainnet/DeployDexalotSimpleSwapCell.s.sol:DeployDexalotSimpleSwapCell --account deployer --rpc-url $CCHAIN_RPC_URL --broadcast --skip-simulation -vvvv --verify --verifier-url 'https://api.routescan.io/v2/network/mainnet/evm/43114/etherscan' --etherscan-api-key "verifyContract"

contract DeployDexalotSimpleSwapCell is TeleporterScriptBase {
    address constant MAINNET_RFQ = 0xEed3c159F3A96aB8d41c8B9cA49EE1e5071A7cdD;
    uint256 constant SWAP_GAS_ESTIMATE = 150_000;
    address constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address public constant TELEPORTER_REGISTRY = 0x7C43605E14F391720e1b37E49C78C4b03A488d98;
    uint256 public constant MIN_TELEPORTER_VERSION = 1;

    function run() external {
        address owner = vm.envAddress("CELL_OWNER");

        vm.startBroadcast();

        new DexalotSimpleSwapCell(
            owner, WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, MAINNET_RFQ, SWAP_GAS_ESTIMATE
        );

        vm.stopBroadcast();
    }
}
