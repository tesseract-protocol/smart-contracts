// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {YakSwapCell} from "./../../../src/YakSwapCell.sol";
import {TeleporterScriptBase} from "../../TeleporterScriptBase.sol";

contract DeployCellCchain is TeleporterScriptBase {
    address public constant YAK_ROUTER = 0xC4729E56b831d74bBc18797e0e17A295fA77488c;
    address public constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address public constant TELEPORTER_REGISTRY = 0x7C43605E14F391720e1b37E49C78C4b03A488d98;
    uint256 public constant MIN_TELEPORTER_VERSION = 1;

    function run() external {
        address owner = vm.envAddress("CELL_OWNER");

        vm.startBroadcast();

        new YakSwapCell(owner, WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, YAK_ROUTER);

        vm.stopBroadcast();
    }
}

// forge script script/deployment/mainnet/DeployCellCchain.s.sol:DeployCellCchain --account deployer --rpc-url $CCHAIN_RPC_URL --broadcast --skip-simulation -vvvv --verify --verifier-url 'https://api.routescan.io/v2/network/mainnet/evm/43114/etherscan' --etherscan-api-key "verifyContract"
