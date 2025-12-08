// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.27;

import {FHE, euint64} from "@fhevm/solidity/lib/FHE.sol";

/**
 * @title SeedCollector
 * @notice Library for collecting internal seeds from blockchain data
 * @dev NO external seeds - only blockchain data + master seed + request data
 */
library SeedCollector {
    /**
     * @notice Generate seed from blockchain data
     * @param requestId Unique request ID
     * @param consumer Consumer address
     * @param tag Request tag
     * @return blockSeed Blockchain-based seed (public uint64)
     */
    function generateBlockSeed(
        uint256 requestId,
        address consumer,
        bytes32 tag
    ) internal view returns (uint64) {
        // Combine multiple blockchain sources for randomness
        bytes32 seedHash = keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao, // PoS randomness (Ethereum post-merge)
            blockhash(block.number > 0 ? block.number - 1 : block.number),
            block.coinbase,
            gasleft(),
            requestId,
            consumer,
            tag
        ));
        
        // Convert to uint64 (take first 8 bytes)
        return uint64(uint256(seedHash));
    }
    
    /**
     * @notice Collect and aggregate all internal seeds
     * @param masterSeed Master system seed (encrypted)
     * @param requestId Unique request ID
     * @param consumer Consumer address
     * @param tag Request tag
     * @return aggregatedSeed Combined seed (encrypted)
     * @dev Simplified: Only use masterSeed + one request seed to minimize FHE operations
     */
    function collectInternalSeeds(
        euint64 masterSeed,
        uint256 requestId,
        address consumer,
        bytes32 tag
    ) internal returns (euint64 aggregatedSeed) {
        // Generate a single request-based seed (for uniqueness)
        uint64 requestSeed = uint64(uint256(keccak256(abi.encodePacked(
            requestId,
            consumer,
            tag,
            block.timestamp
        ))));
        
        // Convert to encrypted and XOR with master seed
        // Only 2 FHE operations: asEuint64 + xor
        euint64 encryptedRequestSeed = FHE.asEuint64(requestSeed);
        aggregatedSeed = FHE.xor(masterSeed, encryptedRequestSeed);
        
        return aggregatedSeed;
    }
}

