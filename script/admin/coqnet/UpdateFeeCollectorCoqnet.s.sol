// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AdminCalls} from "../AdminCalls.sol";
import {TeleporterScriptBase} from "../../TeleporterScriptBase.sol";
import "forge-std/console.sol";
// forge script script/admin/coqnet/UpdateFeeCollectorCoqnet.s.sol:UpdateFeeCollectorCoqnet --account deployer --sender 0x1A267D3f9f5116dF6ae00A4aD698CdcF27b71920 --rpc-url $CCHAIN_RPC_URL --broadcast --skip-simulation -vvvv

contract UpdateFeeCollectorCoqnet is TeleporterScriptBase, AdminCalls {
    bytes32 public constant DESTINATION_BLOCKCHAIN_ID =
        0x898b8aa8353f2b79ee1de07c36474fcee339003d90fa06ea3a90d9e88b7d7c33;
    address public constant TELEPORTER_FEE_TOKEN = address(0);
    uint256 public constant TELEPORTER_FEE_AMOUNT = 0;
    uint256 public constant REQUIRED_GAS_LIMIT = 400_000;

    // Default contract addresses
    address public constant CELL_ADDRESS = 0xDdB71A69Cf1a45d98DFb7E47d78F7eF79E9854dC;
    address public constant NEW_FEE_COLLECTOR = 0xCAe225D77534EF0D20D8E42d97e2FB84002C7F05;

    function run() public {
        vm.startBroadcast();

        updateFeeCollector(
            NEW_FEE_COLLECTOR,
            DESTINATION_BLOCKCHAIN_ID,
            CELL_ADDRESS,
            TELEPORTER_FEE_TOKEN,
            TELEPORTER_FEE_AMOUNT,
            REQUIRED_GAS_LIMIT
        );

        vm.stopBroadcast();
    }
}

// cast call 0xddb71a69cf1a45d98dfb7e47d78f7ef79e9854dc "feeCollector()(address)" --rpc-url $COQNET_RPC_URL
