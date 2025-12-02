// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract BridgePathRegistry is Ownable {
    struct BridgePath {
        address localAddress;
        address remoteAddress;
        bytes32 destinationBlockchainID;
    }

    mapping(address => BridgePath[]) public bridgePaths;
    address[] public availableTokens;

    mapping(bytes32 => address) public cells;

    event SetBridgePath(
        address indexed token, address localAddress, address remoteAddress, bytes32 indexed destinationBlockchainID
    );
    event BridgePathRemoved(address indexed token, bytes32 indexed destinationBlockchainID);
    event SetCell(bytes32 indexed destinationBlockchainID, address indexed cell);
    event CellRemoved(bytes32 indexed destinationBlockchainID);

    function setBridgePath(address token, address localAddress, address remoteAddress, bytes32 destinationBlockchainID)
        external
        onlyOwner
    {
        require(token != address(0), "Invalid token address");
        require(localAddress != address(0), "Invalid local address");
        require(remoteAddress != address(0), "Invalid remote address");
        require(destinationBlockchainID != bytes32(0), "Invalid destination blockchain ID");

        if (bridgePaths[token].length == 0) {
            availableTokens.push(token);
        }

        uint256 index = type(uint256).max;
        for (uint256 i = 0; i < bridgePaths[token].length; i++) {
            if (bridgePaths[token][i].destinationBlockchainID == destinationBlockchainID) {
                index = i;
            }
        }
        if (index < type(uint256).max) {
            bridgePaths[token][index] = BridgePath({
                localAddress: localAddress,
                remoteAddress: remoteAddress,
                destinationBlockchainID: destinationBlockchainID
            });
        } else {
            bridgePaths[token].push(
                BridgePath({
                    localAddress: localAddress,
                    remoteAddress: remoteAddress,
                    destinationBlockchainID: destinationBlockchainID
                })
            );
        }

        emit SetBridgePath(token, localAddress, remoteAddress, destinationBlockchainID);
    }

    function removeBridgePath(address token, bytes32 destinationBlockchainID) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(bridgePaths[token].length < 1, "Bridge path does not exist");

        for (uint256 i = 0; i < bridgePaths[token].length; i++) {
            if (bridgePaths[token][i].destinationBlockchainID == destinationBlockchainID) {
                bridgePaths[token][i] = bridgePaths[token][bridgePaths[token].length - 1];
                bridgePaths[token].pop();
                emit BridgePathRemoved(token, destinationBlockchainID);
                break;
            }
        }

        if (bridgePaths[token].length == 0) {
            for (uint256 i = 0; i < availableTokens.length; i++) {
                if (availableTokens[i] == token) {
                    availableTokens[i] = availableTokens[availableTokens.length - 1];
                    availableTokens.pop();
                    break;
                }
            }
        }
    }

    function setCell(bytes32 destinationBlockchainID, address cell) external onlyOwner {
        require(destinationBlockchainID != bytes32(0), "Invalid destination blockchain ID");
        require(cell != address(0), "Invalid cell address");

        cells[destinationBlockchainID] = cell;

        emit SetCell(destinationBlockchainID, cell);
    }

    function removeCell(bytes32 destinationBlockchainID) external onlyOwner {
        require(destinationBlockchainID != bytes32(0), "Invalid destination blockchain ID");
        require(cells[destinationBlockchainID] != address(0), "Cell does not exist");

        delete cells[destinationBlockchainID];

        emit CellRemoved(destinationBlockchainID);
    }

    function getBridgePaths(address token) external view returns (BridgePath[] memory) {
        return bridgePaths[token];
    }

    function getAllAvailableTokens() external view returns (address[] memory) {
        return availableTokens;
    }
}
