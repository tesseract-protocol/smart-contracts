// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@teleporter/ITeleporterMessenger.sol";
import "@teleporter/ITeleporterReceiver.sol";
import "forge-std/console2.sol";

contract TeleporterMock {
    event SendCrossChainMessage();

    function sendTeleporterMessage(
        address receiver,
        bytes32 sourceBlockchainID,
        address originSenderAddress,
        bytes calldata message
    ) external {
        ITeleporterReceiver(receiver).receiveTeleporterMessage(sourceBlockchainID, originSenderAddress, message);
    }

    function sendCrossChainMessage(TeleporterMessageInput calldata) external returns (bytes32) {
        emit SendCrossChainMessage();
        return "";
    }
}
