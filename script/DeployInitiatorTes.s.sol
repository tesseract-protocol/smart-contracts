// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Script.sol";
import "./../src/Initiator.sol";

contract DeployInitiatorTes is Script {
    address public constant PRIMARY_FEE_TOKEN = 0xB8C177f201B9Fea640cD667c6327aBb756A1D5Ea;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Initiator initiator = new Initiator(PRIMARY_FEE_TOKEN);

        vm.stopBroadcast();
    }
}

// forge script --chain 732 script/DeployInitiatorTes.s.sol:DeployInitiatorTes --rpc-url $TESCHAIN_RPC_URL --broadcast -vvvv
