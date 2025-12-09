const fs = require("fs");
const path = require("path");

const ENV_EXAMPLE = `# Network Configuration
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
# Or use Infura:
# SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY

# Private Key (for deployment)
# ⚠️  Never commit this file with a real private key!
PRIVATE_KEY=your_private_key_here

# Etherscan API Key (for contract verification)
ETHERSCAN_API_KEY=your_etherscan_api_key_here

# Optional: Gas Reporter
# REPORT_GAS=true
# COINMARKETCAP_API_KEY=your_coinmarketcap_api_key
`;

function setup() {
  const envPath = path.join(__dirname, "..", ".env");
  const envExamplePath = path.join(__dirname, "..", ".env.example");

  if (!fs.existsSync(envExamplePath)) {
    fs.writeFileSync(envExamplePath, ENV_EXAMPLE);
    console.log("✅ Created .env.example");
  }

  if (!fs.existsSync(envPath)) {
    fs.writeFileSync(envPath, ENV_EXAMPLE);
    console.log("✅ Created .env file");
    console.log("\n⚠️  Please update .env with your actual values:");
    console.log("   1. SEPOLIA_RPC_URL - Your Sepolia RPC endpoint");
    console.log("   2. PRIVATE_KEY - Your wallet private key (for deployment)");
    console.log("   3. ETHERSCAN_API_KEY - Your Etherscan API key (for verification)");
    console.log("\n📝 Edit .env file and add your credentials");
  } else {
    console.log("ℹ️  .env file already exists");
  }

  console.log("\n✨ Setup complete!");
  console.log("\n📚 Next steps:");
  console.log("   1. Update .env with your credentials");
  console.log("   2. npm install --legacy-peer-deps");
  console.log("   3. npm run compile");
  console.log("   4. npm test");
  console.log("   5. npm run deploy:sepolia");
}

setup();
