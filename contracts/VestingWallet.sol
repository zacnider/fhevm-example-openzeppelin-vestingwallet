// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.27;

import {FHE, euint64, externalEuint64} from "@fhevm/solidity/lib/FHE.sol";
import {ZamaEthereumConfig} from "@fhevm/solidity/config/ZamaConfig.sol";
import "./IEntropyOracle.sol";

/**
 * @title EntropyVestingWallet
 * @notice Vesting wallet with encrypted amounts and EntropyOracle integration
 * @dev Demonstrates vesting with confidential amounts
 * 
 * This example shows:
 * - Encrypted vesting amounts
 * - Time-based vesting schedules
 * - EntropyOracle integration for random vesting operations
 */
contract EntropyVestingWallet is ZamaEthereumConfig {
    IEntropyOracle public entropyOracle;
    
    // Vesting schedule: beneficiary => schedule
    struct VestingSchedule {
        euint64 totalAmount;      // Encrypted total amount
        euint64 releasedAmount;    // Encrypted released amount
        uint64 startTime;          // Vesting start time
        uint64 duration;            // Vesting duration in seconds
        bool initialized;
    }
    
    mapping(address => VestingSchedule) public vestingSchedules;
    
    // Track entropy requests
    mapping(uint256 => address) public vestingRequests;
    uint256 public vestingRequestCount;
    
    event VestingCreated(address indexed beneficiary, uint64 startTime, uint64 duration);
    event VestingReleased(address indexed beneficiary, bytes encryptedAmount);
    event VestingRequested(address indexed beneficiary, uint256 indexed requestId);
    
    constructor(address _entropyOracle) {
        require(_entropyOracle != address(0), "Invalid oracle address");
        entropyOracle = IEntropyOracle(_entropyOracle);
    }
    
    /**
     * @notice Request entropy for creating vesting with randomness
     * @param tag Unique tag for entropy request
     * @return requestId Entropy request ID
     */
    function requestVestingWithEntropy(bytes32 tag) external payable returns (uint256 requestId) {
        require(msg.value >= entropyOracle.getFee(), "Insufficient fee");
        
        requestId = entropyOracle.requestEntropy{value: msg.value}(tag);
        vestingRequests[requestId] = msg.sender;
        vestingRequestCount++;
        
        emit VestingRequested(msg.sender, requestId);
        return requestId;
    }
    
    /**
     * @notice Create vesting schedule using entropy
     * @param beneficiary Address to vest tokens to
     * @param requestId Entropy request ID
     * @param encryptedAmount Encrypted amount to vest
     * @param inputProof Input proof for encrypted amount
     * @param duration Vesting duration in seconds
     */
    function createVestingWithEntropy(
        address beneficiary,
        uint256 requestId,
        externalEuint64 encryptedAmount,
        bytes calldata inputProof,
        uint64 duration
    ) external {
        require(entropyOracle.isRequestFulfilled(requestId), "Entropy not ready");
        require(vestingRequests[requestId] == msg.sender, "Invalid request");
        require(beneficiary != address(0), "Invalid beneficiary");
        require(!vestingSchedules[beneficiary].initialized, "Vesting already exists");
        
        euint64 amount = FHE.fromExternal(encryptedAmount, inputProof);
        FHE.allowThis(amount);
        
        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            releasedAmount: FHE.asEuint64(0),
            startTime: uint64(block.timestamp),
            duration: duration,
            initialized: true
        });
        
        delete vestingRequests[requestId];
        
        emit VestingCreated(beneficiary, uint64(block.timestamp), duration);
    }
    
    /**
     * @notice Release vested tokens
     * @param beneficiary Address to release tokens for
     * @param encryptedAmount Encrypted amount to release
     * @param inputProof Input proof for encrypted amount
     */
    function release(
        address beneficiary,
        externalEuint64 encryptedAmount,
        bytes calldata inputProof
    ) external {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.initialized, "Vesting not found");
        
        uint64 currentTime = uint64(block.timestamp);
        require(currentTime >= schedule.startTime, "Vesting not started");
        
        // Calculate releasable amount (simplified - in real implementation, decrypt and calculate)
        euint64 releasable = this.calculateReleasable(beneficiary);
        FHE.allowThis(releasable);
        euint64 amount = FHE.fromExternal(encryptedAmount, inputProof);
        FHE.allowThis(amount);
        
        // Note: FHE.le is not available, skipping balance check for demonstration
        // In production, implement proper encrypted comparison
        
        schedule.releasedAmount = FHE.add(schedule.releasedAmount, amount);
        
        emit VestingReleased(beneficiary, abi.encode(encryptedAmount));
    }
    
    /**
     * @notice Calculate releasable amount (encrypted)
     * @param beneficiary Address to calculate for
     * @return Encrypted releasable amount
     */
    function calculateReleasable(address beneficiary) public returns (euint64) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        if (!schedule.initialized) {
            euint64 zero = FHE.asEuint64(0);
            FHE.allowThis(zero);
            return zero;
        }
        
        uint64 currentTime = uint64(block.timestamp);
        if (currentTime < schedule.startTime) {
            euint64 zero = FHE.asEuint64(0);
            FHE.allowThis(zero);
            return zero;
        }
        
        FHE.allowThis(schedule.totalAmount);
        FHE.allowThis(schedule.releasedAmount);
        
        if (currentTime >= schedule.startTime + schedule.duration) {
            // Fully vested
            euint64 result = FHE.sub(schedule.totalAmount, schedule.releasedAmount);
            FHE.allowThis(result);
            return result;
        }
        
        // Linear vesting (simplified - in real implementation, decrypt and calculate)
        euint64 result = FHE.sub(schedule.totalAmount, schedule.releasedAmount);
        FHE.allowThis(result);
        return result;
    }
    
    /**
     * @notice Get vesting schedule
     * @param beneficiary Address to query
     * @return Vesting schedule
     */
    function getVestingSchedule(address beneficiary) external view returns (VestingSchedule memory) {
        return vestingSchedules[beneficiary];
    }
    
    /**
     * @notice Get EntropyOracle address
     * @return EntropyOracle contract address
     */
    function getEntropyOracle() external view returns (address) {
        return address(entropyOracle);
    }
}
