import hre from "hardhat";

const ENTROPY_ORACLE_ADDRESS = "0x75b923d7940E1BD6689EbFdbBDCD74C1f6695361";

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", (await hre.ethers.provider.getBalance(deployer.address)).toString());

  console.log(`\nDeploying EntropyVestingWallet...`);
  
  const ContractFactory = await hre.ethers.getContractFactory("EntropyVestingWallet");
  const contract = await ContractFactory.deploy(ENTROPY_ORACLE_ADDRESS);
  
  await contract.waitForDeployment();
  const address = await contract.getAddress();
  
  console.log(`\n✅ EntropyVestingWallet deployed to:`, address);
  console.log(`\n📋 Deployment Details:`);
  console.log(`   Network: ${hre.network.name}`);
  console.log(`   Deployer: ${deployer.address}`);
  console.log(`   Contract: EntropyVestingWallet`);
  console.log(`   Address: ${address}`);
  console.log(`\n🔍 Verify with:`);
  console.log(`   npm run verify ${address}`);
  
  return address;
}

main()
  .then((address) => {
    console.log(`\n✨ Deployment successful!`);
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n❌ Deployment failed:");
    console.error(error);
    process.exit(1);
  });
