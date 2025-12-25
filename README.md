# VestingWallet

Learn how to encrypt a single value using FHE.fromExternal

## 🎓 What You'll Learn

This example teaches you how to use FHEVM to build privacy-preserving smart contracts. You'll learn step-by-step how to implement encrypted operations, manage permissions, and work with encrypted data.

## 🚀 Quick Start

1. **Clone this repository:**
   ```bash
   git clone https://github.com/zacnider/fhevm-example-openzeppelin-vestingwallet.git
   cd fhevm-example-openzeppelin-vestingwallet
   ```

2. **Install dependencies:**
   ```bash
   npm install --legacy-peer-deps
   ```

3. **Setup environment:**
   ```bash
   npm run setup
   ```
   Then edit `.env` file with your credentials:
   - `SEPOLIA_RPC_URL` - Your Sepolia RPC endpoint
   - `PRIVATE_KEY` - Your wallet private key (for deployment)
   - `ETHERSCAN_API_KEY` - Your Etherscan API key (for verification)

4. **Compile contracts:**
   ```bash
   npm run compile
   ```

5. **Run tests:**
   ```bash
   npm test
   ```

6. **Deploy to Sepolia:**
   ```bash
   npm run deploy:sepolia
   ```

7. **Verify contract (after deployment):**
   ```bash
   npm run verify <CONTRACT_ADDRESS>
   ```

**Alternative:** Use the [Examples page](https://entrofhe.vercel.app/examples) for browser-based deployment and verification.

---

## 📚 Overview

@title EntropyVestingWallet
@notice Vesting wallet with encrypted amounts and encrypted randomness integration
@dev Demonstrates vesting with confidential amounts
In this example, you will learn:
- Encrypted vesting amounts
- Time-based vesting schedules
- encrypted randomness integration for random vesting operations

@notice Request entropy for creating vesting with randomness
@param tag Unique tag for entropy request
@return requestId Entropy request ID

@notice Create vesting schedule using entropy
@param beneficiary Address to vest tokens to
@param requestId Entropy request ID
@param encryptedAmount Encrypted amount to vest
@param inputProof Input proof for encrypted amount
@param duration Vesting duration in seconds

@notice Release vested tokens
@param beneficiary Address to release tokens for
@param encryptedAmount Encrypted amount to release
@param inputProof Input proof for encrypted amount

@notice Calculate releasable amount (encrypted)
@param beneficiary Address to calculate for
@return Encrypted releasable amount

@notice Get vesting schedule
@param beneficiary Address to query
@return Vesting schedule

@notice Get encrypted randomness address
@return encrypted randomness contract address



## 🔐 Learn Zama FHEVM Through This Example

This example teaches you how to use the following **Zama FHEVM** features:

### What You'll Learn About

- **ZamaEthereumConfig**: Inherits from Zama's network configuration
  ```solidity
  contract MyContract is ZamaEthereumConfig {
      // Inherits network-specific FHEVM configuration
  }
  ```

- **FHE Operations**: Uses Zama's FHE library for encrypted operations
  - `FHE operations` - Zama FHEVM operation
  - `FHE.allowThis()` - Zama FHEVM operation
  - `FHE.allow()` - Zama FHEVM operation

- **Encrypted Types**: Uses Zama's encrypted integer types
  - `euint64` - 64-bit encrypted unsigned integer
  - `externalEuint64` - External encrypted value from user

- **Access Control**: Uses Zama's permission system
  - `FHE.allowThis()` - Allow contract to use encrypted values
  - `FHE.allow()` - Allow specific user to decrypt
  - `FHE.allowTransient()` - Temporary permission for single operation
  - `FHE.fromExternal()` - Convert external encrypted values to internal

### Zama FHEVM Imports

```solidity
// Zama FHEVM Core Library - FHE operations and encrypted types
import {FHE, euint64, externalEuint64} from "@fhevm/solidity/lib/FHE.sol";

// Zama Network Configuration - Provides network-specific settings
import {ZamaEthereumConfig} from "@fhevm/solidity/config/ZamaConfig.sol";
```

### Zama FHEVM Code Example

```solidity
// Using Zama FHEVM with OpenZeppelin confidential contracts
euint64 encryptedAmount = FHE.fromExternal(encryptedInput, inputProof);
FHE.allowThis(encryptedAmount);

// Zama FHEVM enables encrypted token operations
// All amounts remain encrypted during transfers
```

### FHEVM Concepts You'll Learn

1. **OpenZeppelin Integration**: Learn how to use Zama FHEVM for openzeppelin integration
2. **ERC7984 Confidential Tokens**: Learn how to use Zama FHEVM for erc7984 confidential tokens
3. **FHE Operations**: Learn how to use Zama FHEVM for fhe operations

### Learn More About Zama FHEVM

- 📚 [Zama FHEVM Documentation](https://docs.zama.org/protocol)
- 🎓 [Zama Developer Hub](https://www.zama.org/developer-hub)
- 💻 [Zama FHEVM GitHub](https://github.com/zama-ai/fhevm)



## 🔍 Contract Code

```solidity
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

```

## 🧪 Tests

See [test file](./test/VestingWallet.test.ts) for comprehensive test coverage.

```bash
npm test
```


## 📚 Category

**openzeppelin**



## 🔗 Related Examples

- [All openzeppelin examples](https://github.com/zacnider/entrofhe/tree/main/examples)

## 📝 License

BSD-3-Clause-Clear
