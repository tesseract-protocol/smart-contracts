// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {HopOnlyCell} from "./../../../src/HopOnlyCell.sol";
import {TeleporterScriptBase} from "../../TeleporterScriptBase.sol";

contract DeployCellCoqnet is TeleporterScriptBase {
    address public constant WCOQ = 0x2c76Ab64981E1d4304fC064a7dC3Be4aA3266c98;
    address constant TELEPORTER_REGISTRY = 0xE329B5Ff445E4976821FdCa99D6897EC43891A6c;
    uint256 constant MIN_TELEPORTER_VERSION = 1;

    function run() external {
        address owner = vm.envAddress("CELL_OWNER");

        vm.startBroadcast();

        new HopOnlyCell(owner, WCOQ, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION);

        vm.stopBroadcast();
    }
}

// forge script script/deployment/mainnet/DeployCellCoqnet.s.sol:DeployCellCoqnet --account deployer --rpc-url $COQNET_RPC_URL --broadcast --skip-simulation -vvvv --verifier custom --verify --verifier-url 'https://api.routescan.io/v2/network/mainnet/evm/42069/etherscan' --etherscan-api-key "verifyContract"
