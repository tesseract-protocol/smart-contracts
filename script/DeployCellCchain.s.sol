// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "./../src/YakSwapCell.sol";

contract DeployCellCchain is Script {
    address public constant YAK_ROUTER = 0xC4729E56b831d74bBc18797e0e17A295fA77488c;
    address public constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address public constant TELEPORTER_REGISTRY = 0x7C43605E14F391720e1b37E49C78C4b03A488d98;
    uint256 public constant MIN_TELEPORTER_VERSION = 1;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address owner = vm.envAddress("CELL_OWNER");

        WarpMessengerMock warp = new WarpMessengerMock();
        vm.etch(0x0200000000000000000000000000000000000005, address(warp).code);

        vm.startBroadcast(deployerPrivateKey);

        new YakSwapCell(owner, WAVAX, TELEPORTER_REGISTRY, MIN_TELEPORTER_VERSION, YAK_ROUTER);

        vm.stopBroadcast();
    }
}

contract WarpMessengerMock {
    function getBlockchainID() external returns (bytes32 blockchainID) {}
}

// forge script script/DeployCellCchain.s.sol:DeployCellCchain --rpc-url $CCHAIN_RPC_URL --broadcast --skip-simulation -vvvv --verify --verifier-url 'https://api.routescan.io/v2/network/mainnet/evm/43114/etherscan' --etherscan-api-key "verifyContract"
