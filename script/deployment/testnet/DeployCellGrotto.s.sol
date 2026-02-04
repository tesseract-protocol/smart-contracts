// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TeleporterScriptBase} from "../../TeleporterScriptBase.sol";
import {HopOnlyCell} from "./../../../src/HopOnlyCell.sol";

contract DeployCellGrotto is TeleporterScriptBase {
    address public constant WHERESY = 0x339985DFe05E6796353964fF22Eac0a449c71d00;
    address public constant TELEPORTER_REGISTRY = 0xE329B5Ff445E4976821FdCa99D6897EC43891A6c;
    uint256 public constant MIN_TELEPORTER_VERSION = 1;

    function run() external {
        address owner = vm.envAddress("CELL_OWNER_TESTNET");

        vm.startBroadcast();

        new HopOnlyCell(owner, WHERESY, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION);

        vm.stopBroadcast();
    }
}

// forge script script/deployment/testnet/DeployCellGrotto.s.sol:DeployCellGrotto --account deployer --rpc-url https://subnets.avax.network/thegrotto/testnet/rpc --broadcast --skip-simulation -vvvv
