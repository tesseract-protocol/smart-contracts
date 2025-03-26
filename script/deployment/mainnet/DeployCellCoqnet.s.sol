// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./../../../src/HopOnlyCell.sol";
import {TeleporterScriptBase} from "../../TeleporterScriptBase.sol";

contract DeployCellCoqnet is TeleporterScriptBase {
    address public constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address constant TELEPORTER_REGISTRY = 0xE329B5Ff445E4976821FdCa99D6897EC43891A6c;
    uint256 constant MIN_TELEPORTER_VERSION = 1;

    function run() external {
        address owner = vm.envAddress("CELL_OWNER");

        vm.startBroadcast();

        new HopOnlyCell(owner, WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION);

        vm.stopBroadcast();
    }
}

// forge script script/deployment/mainnet/DeployCellCoqnet.s.sol:DeployCellCoqnet --account deployer --rpc-url $COQNET_RPC_URL --broadcast --skip-simulation -vvvv --verify --verifier-url 'https://api.routescan.io/v2/network/mainnet/evm/42069/etherscan' --etherscan-api-key "verifyContract"

// forge verify-contract 0xb67b78c846BB2863c38867554090Db12134F4119 "src/HopOnlyCell.sol:HopOnlyCell" /
// --verifier-url 'https://api.routescan.io/v2/network/mainnet/evm/42069/etherscan' /
// --etherscan-api-key "verifyContract" /
// --num-of-optimizations 200 /
// --compiler-version 0.8.25 /
// --watch /
// --constructor-args 000000000000000000000000dcedf06fd33e1d7b6eb4b309f779a0e9d3172e44000000000000000000000000b31f66aa3c1e785363f0875a1b74e27b85fd66c7000000000000000000000000e329b5ff445e4976821fdca99d6897ec43891a6c0000000000000000000000000000000000000000000000000000000000000001
