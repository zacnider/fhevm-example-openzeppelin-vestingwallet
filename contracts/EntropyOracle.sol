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

