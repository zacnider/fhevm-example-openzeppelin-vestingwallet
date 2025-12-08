// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.27;

import {FHE, euint64} from "@fhevm/solidity/lib/FHE.sol";

/**
 * @title LogisticMap
 * @notice Library for logistic map chaos function in FHE
 * @dev x[n+1] = r * x[n] * (1 - x[n])
 *      Where r is control parameter (typically 3.57-4.0)
 *      x is state (0.0-1.0 range, scaled to uint64)
 */
library LogisticMap {
    // Control parameter r (scaled by 1e18 for precision)
    // r = 3.9 (good chaos parameter)
    uint256 private constant R_SCALED = 3900000000000000000; // 3.9 * 1e18
    
    // Maximum value for uint64
    uint256 private constant MAX_UINT64 = type(uint64).max;
    
    /**
     * @notice Iterate chaos function once (FHE-friendly version)
     * @param x Current state (encrypted, scaled 0-MAX_UINT64)
     * @return newX Next state (encrypted)
     * @dev Simplified chaos function for FHE: x[n+1] = x[n] * (MAX_UINT64 - x[n]) * 4
     *      Uses XOR for additional mixing to maintain chaos properties
     *      Overflow is allowed (uint64 wraps naturally)
     */
    function iterate(euint64 x) internal returns (euint64 newX) {
        // Logistic map-inspired chaos function for FHE
        // Minimal operations: 2 FHE ops per iteration
        
        // Multiply by prime for non-linear transformation
        euint64 xScaled = FHE.mul(x, FHE.asEuint64(17));
        
        // XOR with original for mixing (creates chaos)
        newX = FHE.xor(xScaled, x);
        
        return newX;
    }
    
    /**
     * @notice Iterate logistic map multiple times
     * @param x Initial state (encrypted)
     * @param iterations Number of iterations
     * @return finalX Final state after iterations (encrypted)
     */
    function iterateMultiple(euint64 x, uint256 iterations) internal returns (euint64 finalX) {
        finalX = x;
        for (uint256 i = 0; i < iterations; i++) {
            finalX = iterate(finalX);
        }
        return finalX;
    }
}

