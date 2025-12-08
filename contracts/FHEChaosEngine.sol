// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.27;

import {FHE, euint64, externalEuint64} from "@fhevm/solidity/lib/FHE.sol";
import {ZamaEthereumConfig} from "@fhevm/solidity/config/ZamaConfig.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/SeedCollector.sol";
import "./libraries/LogisticMap.sol";

/**
 * @title FHEChaosEngine
 * @notice Core FHE-based chaos engine for entropy generation
 * @dev Uses logistic map with internal seeds only (no external seeds)
 */
contract FHEChaosEngine is ZamaEthereumConfig, Ownable {
    using SeedCollector for euint64;
    using LogisticMap for euint64;
    
    // Master seed (encrypted, set by owner)
    euint64 private masterSeed;
    
    // Current state (encrypted, updated with each iteration)
    euint64 private currentState;
    
    // Request counter (for unique seed generation)
    uint256 private requestCounter;
    
    // Master seed initialized flag
    bool private masterSeedInitialized;
    
    // ============ Events ============
    
    event MasterSeedInitialized(address indexed owner);
    event EntropyGenerated(uint256 indexed requestId, address indexed consumer);
    
    // ============ Errors ============
    
    error MasterSeedNotInitialized();
    error InvalidMasterSeed();
    
    // ============ Constructor ============
    
    constructor(address initialOwner) Ownable(initialOwner) {
        masterSeedInitialized = false;
        requestCounter = 0;
    }
    
    // ============ Master Seed Management ============
    
    /**
     * @notice Initialize master seed (owner only, one-time)
     * @param encryptedSeed Encrypted master seed (euint64)
     * @param inputProof Input proof for encrypted seed
     * @dev Master seed is used in every entropy generation
     */
    function initializeMasterSeed(
        externalEuint64 encryptedSeed,
        bytes calldata inputProof
    ) external onlyOwner {
        require(!masterSeedInitialized, "Master seed already initialized");
        
        // Convert external encrypted seed to internal
        euint64 internalSeed = FHE.fromExternal(encryptedSeed, inputProof);
        
        // Allow contract to use encrypted value for FHE operations
        // DO NOT make publicly decryptable - master seed must remain private
        FHE.allowThis(internalSeed);
        FHE.allow(internalSeed, msg.sender);
        
        // Store master seed (encrypted, not publicly decryptable)
        masterSeed = internalSeed;
        
        // Initialize current state with master seed
        currentState = internalSeed;
        
        masterSeedInitialized = true;
        
        emit MasterSeedInitialized(owner());
    }
    
    // ============ Entropy Generation ============
    
    /**
     * @notice Generate entropy using chaos function
     * @param tag Request tag for uniqueness
     * @param consumer Consumer address
     * @param requestId Request ID from EntropyOracle (for seed consistency)
     * @return entropy Encrypted entropy (euint64)
     * @dev Uses internal seeds only: master seed + blockchain data + request data
     */
    function generateEntropy(
        bytes32 tag,
        address consumer,
        uint256 requestId
    ) external returns (euint64 entropy) {
        if (!masterSeedInitialized) revert MasterSeedNotInitialized();
        
        // Collect internal seeds (NO external seeds)
        // Use requestId from EntropyOracle for consistency
        euint64 aggregatedSeed = SeedCollector.collectInternalSeeds(
            masterSeed,
            requestId,
            consumer,
            tag
        );
        
        // Combine with current state
        euint64 combinedSeed = FHE.xor(currentState, aggregatedSeed);
        
        // Iterate chaos function (logistic map)
        // Single iteration to minimize FHE operations
        euint64 newState = LogisticMap.iterate(combinedSeed);
        
        // Allow contract to use new state in next iteration
        FHE.allowThis(newState);
        
        // Allow consumer to decrypt entropy (privacy: only consumer can decrypt)
        FHE.allow(newState, consumer);
        
        // Update current state
        currentState = newState;
        
        // Return entropy (only consumer can decrypt, not publicly decryptable)
        entropy = newState;
        
        emit EntropyGenerated(requestId, consumer);
        
        return entropy;
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Check if master seed is initialized
     * @return initialized True if master seed is set
     */
    function isMasterSeedInitialized() external view returns (bool initialized) {
        return masterSeedInitialized;
    }
    
    /**
     * @notice Get request counter
     * @return counter Current request counter
     */
    function getRequestCounter() external view returns (uint256 counter) {
        return requestCounter;
    }
}

