// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "../src/interfaces/ICell.sol";
import "avalanche-interchain-token-transfer/contracts/src/TokenHome/ERC20TokenHome.sol";
import "avalanche-interchain-token-transfer/contracts/src/TokenHome/NativeTokenHome.sol";
import "avalanche-interchain-token-transfer/contracts/src/interfaces/ITokenTransferrer.sol";
import "avalanche-interchain-token-transfer/contracts/src/interfaces/IERC20TokenTransferrer.sol";
import "avalanche-interchain-token-transfer/contracts/src/interfaces/INativeTokenTransferrer.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "./mocks/TeleporterRegistryMock.sol";
import "./mocks/WarpMessengerMock.sol";

abstract contract BaseTest is Test {
    using stdStorage for StdStorage;

    event SendCrossChainMessage();

    bytes32 public constant CCHAIN_BLOCKCHAIN_ID = 0x0427d4b22a2a78bcddd456742caf91b56badbff985ee19aef14573e7343fd652;
    bytes32 public constant REMOTE_BLOCKCHAIN_ID = 0x7ca356c6720a432ffb58563d59b3424eb441239e373a93a6de9da358b81366f0;
    address public constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    address public constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address public constant YAK = 0x59414b3089ce2AF0010e7523Dea7E2b35d776ec7;
    address public constant WARP_MESSENGER = 0x0200000000000000000000000000000000000005;

    ERC20TokenHome public usdcTokenHome;
    ERC20TokenHome public wavaxTokenHome;
    NativeTokenHome public nativeTokenHome;
    address public randomRemoteAddress;

    TeleporterRegistryMock public teleporterRegistry;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("CCHAIN_RPC_URL"), 52145182);
        WarpMessengerMock warp = new WarpMessengerMock();
        vm.etch(WARP_MESSENGER, address(warp).code);

        teleporterRegistry = new TeleporterRegistryMock();
        usdcTokenHome = new ERC20TokenHome(address(teleporterRegistry), address(this), USDC, 6);
        wavaxTokenHome = new ERC20TokenHome(address(teleporterRegistry), address(this), WAVAX, 18);
        nativeTokenHome = new NativeTokenHome(address(teleporterRegistry), address(this), WAVAX);
        randomRemoteAddress = vm.addr(123456);

        fundBridge(address(usdcTokenHome), USDC, 6);
        fundBridge(address(wavaxTokenHome), WAVAX, 18);
        fundNativeBridge(address(nativeTokenHome), 18);
    }

    function mockReceiveTokens(address cell, address bridge, uint256 amount, CellPayload memory payload) internal {
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
                    recipientGasLimit: 5_000_000,
                    fallbackRecipient: address(this)
                })
            )
        });
        TeleporterMock(teleporterRegistry.getLatestTeleporter()).sendTeleporterMessage(
            bridge, REMOTE_BLOCKCHAIN_ID, randomRemoteAddress, abi.encode(message)
        );
    }

    function mockReceiveNative(address cell, uint256 amount, CellPayload memory payload) internal {
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
                    recipientGasLimit: 5_000_000,
                    fallbackRecipient: address(this)
                })
            )
        });
        TeleporterMock(teleporterRegistry.getLatestTeleporter()).sendTeleporterMessage(
            address(nativeTokenHome), REMOTE_BLOCKCHAIN_ID, randomRemoteAddress, abi.encode(message)
        );
    }

    function fundNativeBridge(address tokenHome, uint8 decimals) internal {
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
        INativeTokenTransferrer(tokenHome).send{value: 1_000_000 * 10 ** decimals}(input);
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
