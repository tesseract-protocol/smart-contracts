// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {TeleporterScriptBase} from "../../TeleporterScriptBase.sol";
import "./../../../src/UniV2Cell.sol";

// source .env && forge script script/deployment/testnet/DeployUniV2CellKite.s.sol:DeployUniV2CellKite --account yak-deployer --rpc-url kite_testnet --skip-simulation -vvvv
// source .env && forge script script/deployment/testnet/DeployUniV2CellKite.s.sol:DeployUniV2CellKite --account yak-deployer --rpc-url kite_testnet --broadcast --skip-simulation -vvvv
contract DeployUniV2CellKite is TeleporterScriptBase {
    address constant WKITE = 0x3bC8f037691Ce1d28c0bB224BD33563b49F99dE8;
    address constant TELEPORTER_REGISTRY = 0xB01eB76f037196b6113b8bC210564394Ab573aa1;
    uint256 constant MIN_TELEPORTER_VERSION = 1;
    address constant UNI_V2_FACTORY = 0x147f235Dde1adcB00Ef8E2D10D98fEd9a091284D;
    address private constant TEST_USDT = 0x0fF5393387ad2f9f691FD6Fd28e07E3969e27e63;
    address private constant TEST_WETH = 0x273cfA50190358639ea7ab3e6bF9c91252132338;

    function run() external {
        address owner = vm.envAddress("CELL_OWNER");

        address[] memory hopTokens = new address[](3);
        hopTokens[0] = TEST_USDT;
        hopTokens[1] = TEST_WETH;
        hopTokens[2] = WKITE;

        vm.startBroadcast();

        new UniV2Cell(
            owner,
            WKITE,
            TELEPORTER_REGISTRY,
            MIN_TELEPORTER_VERSION,
            UNI_V2_FACTORY,
            3,
            120_000,
            hopTokens,
            3
        );

        vm.stopBroadcast();
    }
}
