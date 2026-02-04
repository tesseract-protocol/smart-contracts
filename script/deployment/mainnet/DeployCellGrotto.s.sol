// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TeleporterScriptBase} from "../../TeleporterScriptBase.sol";
import {UniV2Cell} from "./../../../src/UniV2Cell.sol";

contract DeployCellGrotto is TeleporterScriptBase {
    address public constant WHERESY = 0xfA99B368B5fc1f5a061bc393dFf73BE8a097667D;
    address public constant TELEPORTER_REGISTRY = 0xE329B5Ff445E4976821FdCa99D6897EC43891A6c;
    uint256 public constant MIN_TELEPORTER_VERSION = 1;
    address public constant UNIV2_FACTORY = 0x6296358475402719bf3F27Cdf5e2E944C5BE69D1;

    function run() external {
        address owner = vm.envAddress("CELL_OWNER");
        address[] memory hopTokens = new address[](1);
        hopTokens[0] = WHERESY;

        vm.startBroadcast();

        new UniV2Cell(
            owner, WHERESY, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, UNIV2_FACTORY, 3, 120_000, hopTokens, 2
        );

        vm.stopBroadcast();
    }
}

// forge script script/deployment/mainnet/DeployCellGrotto.s.sol:DeployCellGrotto --account deployer --rpc-url https://subnets.avax.network/thegrotto/mainnet/rpc --broadcast --skip-simulation -vvvv
