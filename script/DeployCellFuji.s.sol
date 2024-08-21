// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Script.sol";
import "./../src/YakSwapCell.sol";

contract DeployCellFuji is Script {
    address public constant TELEPORTER_REGISTRY = 0xF86Cb19Ad8405AEFa7d09C778215D2Cb6eBfB228;
    address public constant ROUTER = 0x1e6911E7Eec3b35F9Ebf4183EF6bAbF64d859FF5;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new YakSwapCell(TELEPORTER_REGISTRY, ROUTER);

        vm.stopBroadcast();
    }
}

// forge script --chain 43113 script/DeployCellFuji.s.sol:DeployCellFuji --rpc-url $FUJI_RPC_URL --broadcast -vvvv
