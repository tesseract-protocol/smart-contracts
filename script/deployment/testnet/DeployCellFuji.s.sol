// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TeleporterScriptBase} from "../../TeleporterScriptBase.sol";
import {YakSwapCell} from "./../../../src/YakSwapCell.sol";

contract DeployCellFuji is TeleporterScriptBase {
    address public constant YAK_ROUTER = 0x1e6911E7Eec3b35F9Ebf4183EF6bAbF64d859FF5;
    address public constant WAVAX_FUJI = 0xd00ae08403B9bbb9124bB305C09058E32C39A48c;
    address public constant TELEPORTER_REGISTRY = 0xF86Cb19Ad8405AEFa7d09C778215D2Cb6eBfB228;
    uint256 public constant MIN_TELEPORTER_VERSION = 1;

    function run() external {
        address owner = vm.envAddress("CELL_OWNER_TESTNET");

        vm.startBroadcast();

        new YakSwapCell(owner, WAVAX_FUJI, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, YAK_ROUTER);

        vm.stopBroadcast();
    }
}

// forge script --chain 43113 script/deployment/testnet/DeployCellFuji.s.sol:DeployCellFuji --account deployer_fuji --rpc-url $FUJI_RPC_URL --broadcast --skip-simulation -vvvv --optimize --optimizer-runs 200 --verify --verifier-url 'https://api.routescan.io/v2/network/testnet/evm/43113/etherscan' --etherscan-api-key "verifyContract"
