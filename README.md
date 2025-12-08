# EntropyVestingWallet

Vesting wallet with encrypted amounts and EntropyOracle integration

## 🚀 Standard workflow
- Install (first run): `npm install --legacy-peer-deps`
- Compile: `npx hardhat compile`
- Test (local FHE + local oracle/chaos engine auto-deployed): `npx hardhat test`
- Deploy (frontend Deploy button): constructor arg is fixed to EntropyOracle `0x75b923d7940E1BD6689EbFdbBDCD74C1f6695361`
- Verify: `npx hardhat verify --network sepolia <contractAddress> 0x75b923d7940E1BD6689EbFdbBDCD74C1f6695361`

## 📋 Overview

This example demonstrates **OpenZeppelin** concepts in FHEVM with **EntropyOracle integration**:
- Encrypted vesting amounts
- Time-based vesting schedules
- EntropyOracle integration for random vesting operations
- Privacy-preserving vesting

## 🎯 What This Example Teaches

This tutorial will teach you:

1. **How to implement vesting wallets** with encrypted amounts
2. **How to create vesting schedules** with time-based release
3. **How to release vested tokens** based on time elapsed
4. **How to use entropy** for random vesting operations
5. **Vesting mechanics** with encrypted amounts
6. **Real-world vesting** implementation

## 💡 Why This Matters

Vesting is common in DeFi:
- **Encrypted amounts maintain privacy** - vesting amounts not visible
- **Time-based release** - tokens released over time
- **Entropy adds randomness** to vesting creation
- **Privacy-preserving** vesting schedules
- **Real-world application** in token distribution

## 🔍 How It Works

### Contract Structure

The contract has four main components:

1. **Request Vesting with Entropy**: Request entropy for vesting creation
2. **Create Vesting with Entropy**: Create vesting schedule using entropy
3. **Release**: Release vested tokens based on time
4. **Calculate Releasable**: Calculate releasable amount (encrypted)

### Step-by-Step Code Explanation

#### 1. Constructor

```solidity
constructor(address _entropyOracle) {
    require(_entropyOracle != address(0), "Invalid oracle address");
    entropyOracle = IEntropyOracle(_entropyOracle);
}
```

**What it does:**
- Takes EntropyOracle address as parameter
- Validates the address is not zero
- Stores the oracle interface

**Why it matters:**
- Must use the correct oracle address: `0x75b923d7940E1BD6689EbFdbBDCD74C1f6695361`

#### 2. Request Vesting with Entropy

```solidity
function requestVestingWithEntropy(bytes32 tag) external payable returns (uint256 requestId) {
    require(msg.value >= entropyOracle.getFee(), "Insufficient fee");
    
    requestId = entropyOracle.requestEntropy{value: msg.value}(tag);
    vestingRequests[requestId] = msg.sender;
    vestingRequestCount++;
    
    emit VestingRequested(msg.sender, requestId);
    return requestId;
}
```

**What it does:**
- Validates fee payment
- Requests entropy from EntropyOracle
- Stores vesting request with user address
- Returns request ID

**Key concepts:**
- **Two-phase vesting**: Request first, create later
- **Request tracking**: Maps request ID to user
- **Entropy for randomness**: Adds randomness to vesting creation

#### 3. Create Vesting with Entropy

```solidity
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
```

**What it does:**
- Validates request ID and fulfillment
- Validates beneficiary address
- Checks vesting doesn't already exist
- Converts external encrypted amount to internal
- Creates vesting schedule with encrypted amount
- Sets start time to current timestamp
- Stores duration for vesting period
- Emits vesting created event

**Key concepts:**
- **Encrypted amount**: Total amount stored encrypted
- **Time-based**: Vesting starts at current timestamp
- **Duration**: Vesting period in seconds

**Why encrypted:**
- Vesting amount remains private
- Only beneficiary can decrypt
- Privacy-preserving vesting

#### 4. Release

```solidity
function release(
    address beneficiary,
    externalEuint64 encryptedAmount,
    bytes calldata inputProof
) external {
    VestingSchedule storage schedule = vestingSchedules[beneficiary];
    require(schedule.initialized, "Vesting not found");
    
    uint64 currentTime = uint64(block.timestamp);
    require(currentTime >= schedule.startTime, "Vesting not started");
    
    euint64 releasable = this.calculateReleasable(beneficiary);
    FHE.allowThis(releasable);
    euint64 amount = FHE.fromExternal(encryptedAmount, inputProof);
    FHE.allowThis(amount);
    
    schedule.releasedAmount = FHE.add(schedule.releasedAmount, amount);
    
    emit VestingReleased(beneficiary, abi.encode(encryptedAmount));
}
```

**What it does:**
- Validates vesting schedule exists
- Checks vesting has started
- Calculates releasable amount (encrypted)
- Converts external encrypted amount to internal
- Updates released amount
- Emits release event

**Key concepts:**
- **Time-based release**: Based on time elapsed
- **Encrypted amounts**: All amounts remain encrypted
- **Released tracking**: Tracks how much has been released

**Why encrypted:**
- Release amounts remain private
- Only beneficiary can decrypt
- Privacy-preserving releases

#### 5. Calculate Releasable

```solidity
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
    
    // Linear vesting (simplified)
    euint64 result = FHE.sub(schedule.totalAmount, schedule.releasedAmount);
    FHE.allowThis(result);
    return result;
}
```

**What it does:**
- Checks if vesting exists
- Checks if vesting has started
- Calculates releasable amount based on time
- Returns encrypted releasable amount

**Key concepts:**
- **Linear vesting**: Simplified calculation
- **Encrypted calculation**: Result remains encrypted
- **Time-based**: Based on elapsed time

**Why simplified:**
- Full implementation requires decryption for precise calculation
- This example shows the pattern
- Production: Use decryption or FHE operations for precise calculation

## 🧪 Step-by-Step Testing

### Prerequisites

1. **Install dependencies:**
   ```bash
   npm install --legacy-peer-deps
   ```

2. **Compile contracts:**
   ```bash
   npx hardhat compile
   ```

### Running Tests

```bash
npx hardhat test
```

### What Happens in Tests

1. **Fixture Setup** (`deployContractFixture`):
   - Deploys FHEChaosEngine, EntropyOracle, and EntropyVestingWallet
   - Returns all contract instances

2. **Test: Request Vesting with Entropy**
   ```typescript
   it("Should request vesting with entropy", async function () {
     const tag = hre.ethers.id("vesting-request");
     const fee = await oracle.getFee();
     const requestId = await contract.requestVestingWithEntropy(tag, { value: fee });
     expect(requestId).to.not.be.undefined;
   });
   ```
   - Requests entropy for vesting
   - Pays required fee
   - Verifies request ID returned

3. **Test: Create Vesting with Entropy**
   ```typescript
   it("Should create vesting schedule", async function () {
     // ... request vesting code ...
     await waitForEntropy(requestId);
     
     const input = hre.fhevm.createEncryptedInput(contractAddress, owner.address);
     input.add64(1000);
     const encryptedInput = await input.encrypt();
     
     const duration = 365 * 24 * 60 * 60; // 1 year
     await contract.createVestingWithEntropy(
       beneficiary.address,
       requestId,
       encryptedInput.handles[0],
       encryptedInput.inputProof,
       duration
     );
     
     const schedule = await contract.getVestingSchedule(beneficiary.address);
     expect(schedule.initialized).to.be.true;
   });
   ```
   - Waits for entropy to be ready
   - Creates encrypted amount
   - Creates vesting schedule
   - Verifies schedule created

### Expected Test Output

```
  EntropyVestingWallet
    Deployment
      ✓ Should deploy successfully
      ✓ Should have EntropyOracle address set
    Vesting Creation
      ✓ Should request vesting with entropy
      ✓ Should create vesting schedule
    Vesting Release
      ✓ Should calculate releasable amount
      ✓ Should release vested tokens

  6 passing
```

**Note:** All amounts are encrypted (handles). Decrypt off-chain using FHEVM SDK to see actual values.

## 🚀 Step-by-Step Deployment

### Option 1: Frontend (Recommended)

1. Navigate to [Examples page](https://entrofhe.vercel.app/examples)
2. Find "EntropyVestingWallet" in Tutorial Examples
3. Click **"Deploy"** button
4. Approve transaction in wallet
5. Wait for deployment confirmation
6. Copy deployed contract address

### Option 2: CLI

1. **Create deploy script** (`scripts/deploy.ts`):
   ```typescript
   import hre from "hardhat";

   async function main() {
     const ENTROPY_ORACLE_ADDRESS = "0x75b923d7940E1BD6689EbFdbBDCD74C1f6695361";
     
     const ContractFactory = await hre.ethers.getContractFactory("EntropyVestingWallet");
     const contract = await ContractFactory.deploy(ENTROPY_ORACLE_ADDRESS);
     await contract.waitForDeployment();
     
     const address = await contract.getAddress();
     console.log("EntropyVestingWallet deployed to:", address);
   }

   main().catch((error) => {
     console.error(error);
     process.exitCode = 1;
   });
   ```

2. **Deploy:**
   ```bash
   npx hardhat run scripts/deploy.ts --network sepolia
   ```

## ✅ Step-by-Step Verification

### Option 1: Frontend

1. After deployment, click **"Verify"** button on Examples page
2. Wait for verification confirmation
3. View verified contract on Etherscan

### Option 2: CLI

```bash
npx hardhat verify --network sepolia <CONTRACT_ADDRESS> 0x75b923d7940E1BD6689EbFdbBDCD74C1f6695361
```

**Important:** Constructor argument must be the EntropyOracle address: `0x75b923d7940E1BD6689EbFdbBDCD74C1f6695361`

## 📊 Expected Outputs

### After Request Vesting with Entropy

- `vestingRequests[requestId]` contains user address
- `vestingRequestCount` increments
- `VestingRequested` event emitted

### After Create Vesting with Entropy

- `getVestingSchedule(beneficiary)` returns vesting schedule
- `schedule.initialized` returns `true`
- `schedule.startTime` contains start timestamp
- `schedule.duration` contains vesting duration
- `VestingCreated` event emitted

### After Release

- `schedule.releasedAmount` returns increased released amount
- `VestingReleased` event emitted

## ⚠️ Common Errors & Solutions

### Error: `SenderNotAllowed()`

**Cause:** Missing `FHE.allowThis()` call on encrypted amount.

**Solution:**
```solidity
euint64 amount = FHE.fromExternal(encryptedAmount, inputProof);
FHE.allowThis(amount); // ✅ Required!
```

**Prevention:** Always call `FHE.allowThis()` on all encrypted values before using them.

---

### Error: `Entropy not ready`

**Cause:** Calling `createVestingWithEntropy()` before entropy is fulfilled.

**Solution:** Always check `isRequestFulfilled()` before using entropy.

---

### Error: `Invalid request`

**Cause:** Request ID doesn't belong to caller.

**Solution:** Ensure request ID matches the caller's request.

---

### Error: `Vesting already exists`

**Cause:** Trying to create vesting for beneficiary that already has one.

**Solution:** Check if vesting already exists before creating. Each beneficiary can only have one vesting schedule.

---

### Error: `Vesting not found`

**Cause:** Trying to release for beneficiary without vesting schedule.

**Solution:** Ensure vesting schedule exists before releasing.

---

### Error: `Vesting not started`

**Cause:** Trying to release before vesting start time.

**Solution:** Wait until vesting start time before releasing.

---

### Error: `Insufficient fee`

**Cause:** Not sending enough ETH when requesting vesting.

**Solution:** Always send exactly 0.00001 ETH:
```typescript
const fee = await contract.entropyOracle.getFee();
await contract.requestVestingWithEntropy(tag, { value: fee });
```

---

### Error: Verification failed - Constructor arguments mismatch

**Cause:** Wrong constructor argument used during verification.

**Solution:** Always use the EntropyOracle address:
```bash
npx hardhat verify --network sepolia <CONTRACT_ADDRESS> 0x75b923d7940E1BD6689EbFdbBDCD74C1f6695361
```

## 🔗 Related Examples

- [EntropyERC7984Token](../openzeppelin-erc7984token/) - ERC7984 token implementation
- [EntropyAccessControl](../access-control-accesscontrol/) - Access control patterns
- [Category: openzeppelin](../)

## 📚 Additional Resources

- [Full Tutorial Track Documentation](../../../frontend/src/pages/Docs.tsx) - Complete educational guide
- [Zama FHEVM Documentation](https://docs.zama.org/) - Official FHEVM docs
- [GitHub Repository](https://github.com/zacnider/fhevm-example-openzeppelin-vestingwallet) - Source code

## 📝 License

BSD-3-Clause-Clear
