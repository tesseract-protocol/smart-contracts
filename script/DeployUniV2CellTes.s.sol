// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Script.sol";
import "./../src/UniV2Cell.sol";

contract DeployUniV2CellTes is Script {
    address constant WTES = 0x00Af5F49a934dd2f0e2fE5fA1F9D23D200Da7f82;
    address constant FACTORY = 0x251EAef319946EF4307f003c1569d70D3143CBE8;
    address private constant WAVAX_TES = 0x4730D16278C5bFB6f4326b8D2d2a9B3Ad3feF098;
    address private constant USDC_TES = 0xC4726bEe045A2e0D447a8B1aCB088dA03BF1A5DD;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        WarpMessengerMock warp = new WarpMessengerMock();
        vm.etch(0x0200000000000000000000000000000000000005, address(warp).code);

        vm.startBroadcast(deployerPrivateKey);

        address[] memory hopTokens = new address[](2);
        hopTokens[0] = WAVAX_TES;
        hopTokens[1] = USDC_TES;
        UniV2Cell cell = new UniV2Cell(vm.addr(1), WTES, FACTORY, 3, 120_000, hopTokens, 3);

        vm.stopBroadcast();
    }
}

contract WarpMessengerMock {
    function getBlockchainID() external returns (bytes32 blockchainID) {}
}

// forge script --chain 900090009000 script/DeployUniV2CellTes.s.sol:DeployUniV2CellTes --rpc-url $TESCHAIN_RPC_URL --broadcast --skip-simulation -vvvv
