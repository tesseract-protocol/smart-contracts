// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Script.sol";
import "./../src/BridgePathRegistry.sol";

contract DeployBridgePathRegistry is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new BridgePathRegistry();

        vm.stopBroadcast();
    }
}

// forge script --chain 732 script/DeployBridgePathRegistryTes.s.sol:DeployBridgePathRegistryTes --rpc-url $TESCHAIN_RPC_URL --broadcast -vvvv

// cast send 0xba34c05620ec502f4d48804eff86599c64ed725e "setBridgePath(address,address,address,bytes32)" 0x33be589E446709E411684Cb3B25E5CA2Ebedcfc0 0x33be589E446709E411684Cb3B25E5CA2Ebedcfc0 0x00aF781618d696412A3B4287a9BaF922acc7DddE 0x7fc93d85c6d62c5b2ac0b519c87010ea5294012d1e407030d6acd0021cac10d5 --rpc-url $TESCHAIN_RPC_URL --private-key $PRIVATE_KEY
// cast send 0xba34c05620ec502f4d48804eff86599c64ed725e "setBridgePath(address,address,address,bytes32)" 0x6598E8dCA0BCA6AcEB41d4E004e5AaDef9B24293 0x6598E8dCA0BCA6AcEB41d4E004e5AaDef9B24293 0x801B217A93b7E6CC4D390dDFA91391083723F060 0x7fc93d85c6d62c5b2ac0b519c87010ea5294012d1e407030d6acd0021cac10d5 --rpc-url $TESCHAIN_RPC_URL --private-key $PRIVATE_KEY
