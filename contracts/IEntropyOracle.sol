// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.27;

import {euint64} from "@fhevm/solidity/lib/FHE.sol";

/**
 * @title IEntropyOracle
 * @notice Interface for Entropy Oracle - Developer-friendly entropy source
 * @dev Developers integrate this interface to request encrypted entropy
 */
interface IEntropyOracle {
    /**
     * @notice Request entropy (main function for developers)
     * @param tag Unique tag for this request (e.g., keccak256("lottery-draw"))
     * @return requestId Unique request ID
     * @dev Requires 0.00001 ETH fee
     */
    function requestEntropy(bytes32 tag) external payable returns (uint256 requestId);
    
    /**
     * @notice Get encrypted entropy for a request
     * @param requestId Request ID returned from requestEntropy
     * @return entropy Encrypted entropy (euint64)
     * @dev Returns encrypted value - use in FHE operations
     */
    function getEncryptedEntropy(uint256 requestId) external view returns (euint64);
    
    /**
     * @notice Check if request is fulfilled
     * @param requestId Request ID
     * @return fulfilled True if entropy is ready
     */
    function isRequestFulfilled(uint256 requestId) external view returns (bool);
    
    /**
     * @notice Get request details
     * @param requestId Request ID
     * @return consumer Consumer address
     * @return tag Request tag
     * @return timestamp Request timestamp
     * @return fulfilled Fulfillment status
     */
    function getRequest(uint256 requestId) external view returns (
        address consumer,
        bytes32 tag,
        uint256 timestamp,
        bool fulfilled
    );
    
    /**
     * @notice Get current fee amount
     * @return fee Fee in wei (0.00001 ETH = 10000000000000 wei)
     */
    function getFee() external pure returns (uint256);
}


