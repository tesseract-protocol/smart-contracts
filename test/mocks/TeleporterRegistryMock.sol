// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./TeleporterMock.sol";

contract TeleporterRegistryMock {
    uint256 public constant latestVersion = 1;

    address immutable teleporterMessenger;

    constructor() {
        teleporterMessenger = address(new TeleporterMock());
    }

    function getVersionFromAddress(address) public pure returns (uint256) {
        return 1;
    }

    function getLatestTeleporter() external view returns (address) {
        return teleporterMessenger;
    }
}
