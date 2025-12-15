# EntropyOracle

Main oracle contract for entropy requests - Developer-friendly interface

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

## 📋 Overview

@title EntropyOracle
@notice Main oracle contract for entropy requests - Developer-friendly interface
@dev Developers call requestEntropy() with 0.00001 ETH fee

@notice Deploy EntropyOracle
@param _chaosEngine Address of FHEChaosEngine contract
@param _feeRecipient Address to receive fees
@param initialOwner Initial owner address

@notice Request entropy - Main function for developers
@param tag Unique tag for this request (e.g., keccak256("lottery-draw"))
@return requestId Unique request ID
@dev Requires exactly 0.00001 ETH fee

@notice Get encrypted entropy for a request
@param requestId Request ID returned from requestEntropy
@return entropy Encrypted entropy (euint64)

@notice Check if request is fulfilled
@param requestId Request ID
@return fulfilled True if entropy is ready

@notice Get request details
@param requestId Request ID
@return consumer Consumer address
@return tag Request tag
@return timestamp Request timestamp
@return fulfilled Fulfillment status

@notice Get current fee amount
@return fee Fee in wei (0.00001 ETH = 10000000000000 wei)

@notice Update fee recipient (owner only)
@param newRecipient New fee recipient address

@notice Update chaos engine (owner only, emergency use)
@param newEngine New chaos engine address

@notice Emergency withdraw (owner only)
@param to Recipient address
@param amount Amount to withdraw



## 🔐 Zama FHEVM Usage

This example demonstrates the following **Zama FHEVM** features:

### Zama FHEVM Features Used

- **ZamaEthereumConfig**: Inherits from Zama's network configuration
  ```solidity
  contract MyContract is ZamaEthereumConfig {
      // Inherits network-specific FHEVM configuration
  }
  ```

- **FHE Operations**: Uses Zama's FHE library for encrypted operations
  - `FHE.add()` - Zama FHEVM operation
  - `FHE.sub()` - Zama FHEVM operation
  - `FHE.mul()` - Zama FHEVM operation
  - `FHE.eq()` - Zama FHEVM operation
  - `FHE.xor()` - Zama FHEVM operation

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
// Using Zama FHEVM's encrypted integer type
euint64 private encryptedValue;

// Converting external encrypted value to internal (Zama FHEVM)
euint64 internalValue = FHE.fromExternal(encryptedValue, inputProof);
FHE.allowThis(internalValue); // Zama FHEVM permission system

// Performing encrypted operations using Zama FHEVM
euint64 result = FHE.add(encryptedValue, FHE.asEuint64(1));
FHE.allowThis(result);
```

### Zama FHEVM Concepts Demonstrated

1. **Encrypted Arithmetic**: Using Zama FHEVM to encrypted arithmetic
2. **Encrypted Comparison**: Using Zama FHEVM to encrypted comparison
3. **External Encryption**: Using Zama FHEVM to external encryption
4. **Permission Management**: Using Zama FHEVM to permission management
5. **Entropy Integration**: Using Zama FHEVM to entropy integration

### Learn More About Zama FHEVM

- 📚 [Zama FHEVM Documentation](https://docs.zama.org/protocol)
- 🎓 [Zama Developer Hub](https://www.zama.org/developer-hub)
- 💻 [Zama FHEVM GitHub](https://github.com/zama-ai/fhevm)


## 🔍 Contract Code

```solidity
// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.27;

import {FHE, euint64} from "@fhevm/solidity/lib/FHE.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./IEntropyOracle.sol";
import "./FHEChaosEngine.sol";

/**
 * @title EntropyOracle
 * @notice Main oracle contract for entropy requests - Developer-friendly interface
 * @dev Developers call requestEntropy() with 0.00001 ETH fee
 */
contract EntropyOracle is IEntropyOracle, Ownable, ReentrancyGuard {
    // ============ Constants ============
    
    /// @notice Fee per entropy request: 0.00001 ETH = 10000000000000 wei
    uint256 public constant FEE_AMOUNT = 0.00001 ether; // 10000000000000 wei
    
    // ============ State Variables ============
    
    /// @notice Core chaos engine
    FHEChaosEngine public chaosEngine;
    
    /// @notice Fee recipient address
    address public feeRecipient;
    
    /// @notice Request counter
    uint256 private requestCounter;
    
    /// @notice Request structure
    struct EntropyRequest {
        address consumer;
        bytes32 tag;
        euint64 encryptedEntropy;
        uint256 timestamp;
        bool fulfilled;
    }
    
    /// @notice Mapping of request ID to request
    mapping(uint256 => EntropyRequest) public requests;
    
    // ============ Events ============
    
    event EntropyRequested(
        uint256 indexed requestId,
        bytes32 indexed hashedConsumer, // Hashed consumer address for privacy
        bytes32 hashedTag,              // Hashed tag for privacy
        uint256 feePaid
    );
    
    event EntropyFulfilled(
        uint256 indexed requestId,
        bytes32 indexed hashedConsumer, // Hashed consumer address for privacy
        bytes32 hashedTag               // Hashed tag for privacy
    );
    
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event ChaosEngineUpdated(address indexed oldEngine, address indexed newEngine);
    
    // ============ Errors ============
    
    error InsufficientFee(uint256 required, uint256 provided);
    error ChaosEngineNotSet();
    error RequestNotFulfilled(uint256 requestId);
    error InvalidAddress();
    
    // ============ Constructor ============
    
    /**
     * @notice Deploy EntropyOracle
     * @param _chaosEngine Address of FHEChaosEngine contract
     * @param _feeRecipient Address to receive fees
     * @param initialOwner Initial owner address
     */
    constructor(
        address _chaosEngine,
        address _feeRecipient,
        address initialOwner
    ) Ownable(initialOwner) {
        if (_chaosEngine == address(0)) revert InvalidAddress();
        if (_feeRecipient == address(0)) revert InvalidAddress();
        
        chaosEngine = FHEChaosEngine(_chaosEngine);
        feeRecipient = _feeRecipient;
        requestCounter = 0;
    }
    
    // ============ Main Function (Developer Interface) ============
    
    /**
     * @notice Request entropy - Main function for developers
     * @param tag Unique tag for this request (e.g., keccak256("lottery-draw"))
     * @return requestId Unique request ID
     * @dev Requires exactly 0.00001 ETH fee
     */
    function requestEntropy(bytes32 tag) 
        external 
        payable 
        nonReentrant 
        returns (uint256 requestId) 
    {
        // Check fee
        if (msg.value < FEE_AMOUNT) {
            revert InsufficientFee(FEE_AMOUNT, msg.value);
        }
        
        // Increment request counter
        requestCounter++;
        requestId = requestCounter;
        
        // Generate entropy using chaos engine
        // Pass requestId for seed consistency
        euint64 entropy = chaosEngine.generateEntropy(tag, msg.sender, requestId);
        
        // Store request
        requests[requestId] = EntropyRequest({
            consumer: msg.sender,
            tag: tag,
            encryptedEntropy: entropy,
            timestamp: block.timestamp,
            fulfilled: true
        });
        
        // Transfer fee to recipient
        if (feeRecipient != address(0)) {
            (bool success, ) = payable(feeRecipient).call{value: msg.value}("");
            require(success, "Fee transfer failed");
        }
        
        // Hash sensitive data for privacy in events
        // Consumer: hash address for privacy
        bytes32 hashedConsumer = keccak256(abi.encodePacked(msg.sender));
        
        // Tag: hash the tag for privacy
        bytes32 hashedTag = keccak256(abi.encodePacked(tag));
        
        emit EntropyRequested(requestId, hashedConsumer, hashedTag, msg.value);
        emit EntropyFulfilled(requestId, hashedConsumer, hashedTag);
        
        return requestId;
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get encrypted entropy for a request
     * @param requestId Request ID returned from requestEntropy
     * @return entropy Encrypted entropy (euint64)
     */
    function getEncryptedEntropy(uint256 requestId) 
        external 
        view 
        returns (euint64) 
    {
        if (!requests[requestId].fulfilled) {
            revert RequestNotFulfilled(requestId);
        }
        return requests[requestId].encryptedEntropy;
    }
    
    /**
     * @notice Check if request is fulfilled
     * @param requestId Request ID
     * @return fulfilled True if entropy is ready
     */
    function isRequestFulfilled(uint256 requestId) 
        external 
        view 
        returns (bool) 
    {
        return requests[requestId].fulfilled;
    }
    
    /**
     * @notice Get request details
     * @param requestId Request ID
     * @return consumer Consumer address
     * @return tag Request tag
     * @return timestamp Request timestamp
     * @return fulfilled Fulfillment status
     */
    function getRequest(uint256 requestId) 
        external 
        view 
        returns (
            address consumer,
            bytes32 tag,
            uint256 timestamp,
            bool fulfilled
        ) 
    {
        EntropyRequest memory request = requests[requestId];
        return (
            request.consumer,
            request.tag,
            request.timestamp,
            request.fulfilled
        );
    }
    
    /**
     * @notice Get current fee amount
     * @return fee Fee in wei (0.00001 ETH = 10000000000000 wei)
     */
    function getFee() external pure returns (uint256) {
        return FEE_AMOUNT;
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Update fee recipient (owner only)
     * @param newRecipient New fee recipient address
     */
    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert InvalidAddress();
        
        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;
        
        emit FeeRecipientUpdated(oldRecipient, newRecipient);
    }
    
    /**
     * @notice Update chaos engine (owner only, emergency use)
     * @param newEngine New chaos engine address
     */
    function setChaosEngine(address newEngine) external onlyOwner {
        if (newEngine == address(0)) revert InvalidAddress();
        
        address oldEngine = address(chaosEngine);
        chaosEngine = FHEChaosEngine(newEngine);
        
        emit ChaosEngineUpdated(oldEngine, newEngine);
    }
    
    /**
     * @notice Emergency withdraw (owner only)
     * @param to Recipient address
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert InvalidAddress();
        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "Withdraw failed");
    }
}


```



## 📚 Category

**openzeppelin**



## 🔗 Related Examples

- [All openzeppelin examples](https://github.com/zacnider/entrofhe/tree/main/examples)

## 📝 License

BSD-3-Clause-Clear
