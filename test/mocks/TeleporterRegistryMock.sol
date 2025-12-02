// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TeleporterMock} from "./TeleporterMock.sol";

contract TeleporterRegistryMock {
    address immutable teleporterMessenger;

    constructor() {
        teleporterMessenger = address(new TeleporterMock());
    }

    function latestVersion() public pure returns (uint256) {
        return 1;
    }

    function getVersionFromAddress(address) public pure returns (uint256) {
        return 1;
    }

    function getLatestTeleporter() external view returns (address) {
        return teleporterMessenger;
    }
}
