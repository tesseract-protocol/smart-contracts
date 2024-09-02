// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

contract WarpMessengerMock {
    function getBlockchainID() external pure returns (bytes32 blockchainID) {
        return 0x7fc93d85c6d62c5b2ac0b519c87010ea5294012d1e407030d6acd0021cac10d5;
    }
}
