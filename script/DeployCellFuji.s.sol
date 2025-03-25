// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "./../src/YakSwapCell.sol";

contract DeployCellFuji is Script {
    address public constant YAK_ROUTER = 0x1e6911E7Eec3b35F9Ebf4183EF6bAbF64d859FF5;
    address public constant WAVAX_FUJI = 0xd00ae08403B9bbb9124bB305C09058E32C39A48c;
    address public constant TELEPORTER_REGISTRY = 0xF86Cb19Ad8405AEFa7d09C778215D2Cb6eBfB228;
    uint256 public constant MIN_TELEPORTER_VERSION = 1;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        WarpMessengerMock warp = new WarpMessengerMock();
        vm.etch(0x0200000000000000000000000000000000000005, address(warp).code);

        vm.startBroadcast(deployerPrivateKey);

        new YakSwapCell(
            vm.addr(deployerPrivateKey), WAVAX_FUJI, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, YAK_ROUTER
        );

        vm.stopBroadcast();
    }
}

contract WarpMessengerMock {
    function getBlockchainID() external returns (bytes32 blockchainID) {}
}

// forge script --chain 43113 script/DeployCellFuji.s.sol:DeployCellFuji --rpc-url $FUJI_RPC_URL --broadcast --skip-simulation -vvvv --optimize --optimizer-runs 200 --verify --verifier-url 'https://api.routescan.io/v2/network/testnet/evm/43113/etherscan' --etherscan-api-key "verifyContract"
