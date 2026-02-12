const fs = require('fs');
const path = require('path');

// Define contracts with their file paths and output names
const contracts = [
  // Core contracts
  { name: 'BettingCore', file: 'BettingCore.sol' },
  { name: 'GameCore', file: 'GameCore.sol' },
  { name: 'LiquidityCore', file: 'LiquidityCore.sol' },

  // Periphery contracts
  { name: 'SeasonPredictor', file: 'SeasonPredictor.sol' },
  { name: 'BettingRouter', file: 'BettingRouter.sol' },
  { name: 'LPRouter', file: 'LPRouter.sol' },
  { name: 'SwapRouter', file: 'SwapRouter.sol' },

  // Token contracts
  { name: 'LeagueBetToken', file: 'LeagueBetToken.sol' },
  { name: 'TokenRegistry', file: 'TokenRegistry.sol' }
];

// Create abis directory if it doesn't exist
const abisDir = path.join(__dirname, 'abis');
if (!fs.existsSync(abisDir)) {
  fs.mkdirSync(abisDir, { recursive: true });
}

let successCount = 0;
let failCount = 0;

contracts.forEach(({ name, file }) => {
  try {
    const jsonPath = path.join(__dirname, `out/${file}/${name}.json`);

    if (!fs.existsSync(jsonPath)) {
      console.log(`⚠️  Skipping ${name} - file not found: ${jsonPath}`);
      failCount++;
      return;
    }

    const json = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
    const outputPath = path.join(abisDir, `${name}.json`);

    fs.writeFileSync(outputPath, JSON.stringify(json.abi, null, 2));
    console.log(`✅ Extracted ABI for ${name}`);
    successCount++;
  } catch (error) {
    console.error(`❌ Error extracting ${name}:`, error.message);
    failCount++;
  }
});

console.log('\n' + '='.repeat(50));
console.log(`ABI Extraction Complete!`);
console.log(`✅ Success: ${successCount} contracts`);
if (failCount > 0) {
  console.log(`⚠️  Skipped/Failed: ${failCount} contracts`);
}
console.log('='.repeat(50));
