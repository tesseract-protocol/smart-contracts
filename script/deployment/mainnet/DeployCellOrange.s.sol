// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./../../../src/HopOnlyCell.sol";
import {TeleporterScriptBase} from "../../TeleporterScriptBase.sol";
import "forge-std/console.sol";

contract DeployCellOrange is TeleporterScriptBase {
    address public constant JUICE = 0x07fE5886dc5397F3d2b0406B1b1de071b5463870;
    address constant TELEPORTER_REGISTRY = 0xE329B5Ff445E4976821FdCa99D6897EC43891A6c;
    uint256 constant MIN_TELEPORTER_VERSION = 1;

    function run() external {
        address owner = vm.envAddress("CELL_OWNER");
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");

        vm.startBroadcast();

        // Use deployer address here
        console.log("Deployer address:", deployer);

        HopOnlyCell cell = new HopOnlyCell(deployer, JUICE, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION);

        cell.updateBaseFeeBips(10);

        cell.transferOwnership(owner);

        vm.stopBroadcast();
    }
}

// forge script script/deployment/mainnet/DeployCellOrange.s.sol:DeployCellOrange --account deployer --rpc-url https://subnets.avax.network/orange/mainnet/rpc --broadcast --skip-simulation -vvvv
