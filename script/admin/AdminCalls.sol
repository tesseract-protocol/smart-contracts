// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ITeleporterMessenger, TeleporterMessageInput, TeleporterFeeInfo} from "@teleporter/ITeleporterMessenger.sol";
import {TeleporterRegistry} from "@teleporter/registry/TeleporterRegistry.sol";
import {Cell} from "../../src/Cell.sol";

contract AdminCalls {
    address public constant TELEPORTER_REGISTRY = 0x7C43605E14F391720e1b37E49C78C4b03A488d98;

    function updateFeeCollector(
        address newFeeCollector,
        bytes32 destinationBlockchainID,
        address destinationAddress,
        address feeTokenAddress,
        uint256 amount,
        uint256 requiredGasLimit
    ) internal {
        TeleporterRegistry registry = TeleporterRegistry(TELEPORTER_REGISTRY);
        ITeleporterMessenger messenger = registry.getLatestTeleporter();

        bytes memory message = abi.encode(Cell.AdminMessageType.UPDATE_FEE_COLLECTOR, abi.encode(newFeeCollector));

        messenger.sendCrossChainMessage(
            TeleporterMessageInput({
                destinationBlockchainID: destinationBlockchainID,
                destinationAddress: destinationAddress,
                feeInfo: TeleporterFeeInfo({feeTokenAddress: feeTokenAddress, amount: amount}),
                requiredGasLimit: requiredGasLimit,
                allowedRelayerAddresses: new address[](0),
                message: message
            })
        );
    }
}
