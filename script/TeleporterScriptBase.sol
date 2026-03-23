// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";

abstract contract TeleporterScriptBase is Script {
    function setUp() public {
        WarpMessengerMock warp = new WarpMessengerMock();
        vm.etch(0x0200000000000000000000000000000000000005, address(warp).code);
    }
}

contract WarpMessengerMock {
    function getBlockchainID() external returns (bytes32 blockchainID) {}
    function sendWarpMessage(bytes calldata payload) external returns (bytes32 messageID) {}
}
