// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {HopOnlyCell} from "./../../../src/HopOnlyCell.sol";
import {TeleporterScriptBase} from "../../TeleporterScriptBase.sol";

contract DeployCellBlazeChain is TeleporterScriptBase {
    address public constant WBLAZE = 0xb5DAc0dEE18fF7C3535Cd565356b1b5e2b460966;
    address constant TELEPORTER_REGISTRY = 0xE329B5Ff445E4976821FdCa99D6897EC43891A6c;
    uint256 constant MIN_TELEPORTER_VERSION = 1;

    function run() external {
        address owner = vm.envAddress("CELL_OWNER");

        vm.startBroadcast();

        new HopOnlyCell(owner, WBLAZE, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION);

        vm.stopBroadcast();
    }
}

// forge script script/deployment/blaze/DeployCellBlazeChain.s.sol:DeployCellBlazeChain --account deployer --rpc-url https://subnets.avax.network/blaze/mainnet/rpc --broadcast --skip-simulation -vvvv --verifier custom --verify --verifier-url 'https://api.routescan.io/v2/network/mainnet/evm/46975/etherscan' --etherscan-api-key "verifyContract"
