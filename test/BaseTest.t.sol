// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "@avalanche-interchain-token-transfer/interfaces/IERC20TokenTransferrer.sol";
import "avalanche-interchain-token-transfer/contracts/src/TokenHome/ERC20TokenHome.sol";
import "avalanche-interchain-token-transfer/contracts/src/interfaces/ITokenTransferrer.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "./../src/HopOnlyCell.sol";
import "./mocks/TeleporterRegistryMock.sol";
import "./mocks/WarpMessengerMock.sol";

abstract contract BaseTest is Test {
    using stdStorage for StdStorage;

    event SendCrossChainMessage();

    bytes32 public constant CCHAIN_BLOCKCHAIN_ID = 0x0427d4b22a2a78bcddd456742caf91b56badbff985ee19aef14573e7343fd652;
    bytes32 public constant REMOTE_BLOCKCHAIN_ID = 0x6b1e340aeda6d5780cef4e45728665efa61057acc52fb862b75def9190974288;
    address public constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    address public constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address public constant WARP_MESSENGER = 0x0200000000000000000000000000000000000005;

    ERC20TokenHome public usdcTokenHome;
    ERC20TokenHome public wavaxTokenHome;
    address public randomRemoteAddress;

    TeleporterRegistryMock public teleporterRegistry = new TeleporterRegistryMock();

    function setUp() public {
        WarpMessengerMock warp = new WarpMessengerMock();
        vm.etch(WARP_MESSENGER, address(warp).code);

        usdcTokenHome = new ERC20TokenHome(address(teleporterRegistry), address(this), USDC, 6);
        wavaxTokenHome = new ERC20TokenHome(address(teleporterRegistry), address(this), WAVAX, 18);
        randomRemoteAddress = vm.addr(123456);

        fundBridge(address(usdcTokenHome), USDC, 6);
        fundBridge(address(wavaxTokenHome), WAVAX, 18);
    }

    function mockReceiveTokens(address cell, uint256 amount, CellPayload memory payload) internal {
        TransferrerMessage memory message = TransferrerMessage({
            messageType: TransferrerMessageType.SINGLE_HOP_CALL,
            payload: abi.encode(
                SingleHopCallMessage({
                    sourceBlockchainID: REMOTE_BLOCKCHAIN_ID,
                    originTokenTransferrerAddress: randomRemoteAddress,
                    originSenderAddress: address(0),
                    recipientContract: address(cell),
                    amount: amount,
                    recipientPayload: abi.encode(payload),
                    recipientGasLimit: 400_000,
                    fallbackRecipient: address(this)
                })
            )
        });
        TeleporterMock(teleporterRegistry.getLatestTeleporter()).sendTeleporterMessage(
            address(usdcTokenHome), REMOTE_BLOCKCHAIN_ID, randomRemoteAddress, abi.encode(message)
        );
    }

    function fundBridge(address tokenHome, address token, uint8 decimals) internal {
        TransferrerMessage memory registerMessage = TransferrerMessage({
            messageType: TransferrerMessageType.REGISTER_REMOTE,
            payload: abi.encode(
                RegisterRemoteMessage({
                    initialReserveImbalance: 0,
                    homeTokenDecimals: decimals,
                    remoteTokenDecimals: decimals
                })
            )
        });
        TeleporterMock(teleporterRegistry.getLatestTeleporter()).sendTeleporterMessage(
            tokenHome, REMOTE_BLOCKCHAIN_ID, randomRemoteAddress, abi.encode(registerMessage)
        );

        SendTokensInput memory input = SendTokensInput({
            destinationBlockchainID: REMOTE_BLOCKCHAIN_ID,
            destinationTokenTransferrerAddress: randomRemoteAddress,
            recipient: address(this),
            primaryFeeTokenAddress: WAVAX,
            primaryFee: 0,
            secondaryFee: 0,
            requiredGasLimit: 400_000,
            multiHopFallback: address(0)
        });
        writeTokenBalance(address(this), token, 1_000_000 * 10 ** decimals);
        IERC20(token).approve(tokenHome, 1_000_000 * 10 ** decimals);
        IERC20TokenTransferrer(tokenHome).send(input, 1_000_000 * 10 ** decimals);
    }

    function writeTokenBalance(address _receiver, address _token, uint256 _amount) internal {
        stdstore.target(_token).sig(IERC20(_token).balanceOf.selector).with_key(_receiver).checked_write(_amount);
    }
}
