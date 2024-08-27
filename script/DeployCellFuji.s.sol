// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Script.sol";
import "./../src/YakSwapCell.sol";

contract DeployCellFuji is Script {
    address public constant ROUTER = 0x1e6911E7Eec3b35F9Ebf4183EF6bAbF64d859FF5;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new YakSwapCell(ROUTER);

        vm.stopBroadcast();
    }
}

// forge script --chain 43113 script/DeployCellFuji.s.sol:DeployCellFuji --rpc-url $FUJI_RPC_URL --broadcast -vvvv
