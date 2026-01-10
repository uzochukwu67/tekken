const fs = require('fs');
const path = require('path');

const contracts = ['GameEngine', 'BettingPool', 'LiquidityPool', 'LeagueToken'];

contracts.forEach(name => {
  const jsonPath = path.join(__dirname, `out/${name}.sol/${name}.json`);
  const json = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
  const outputPath = path.join(__dirname, `frontend/lib/abis/${name}.json`);
  fs.writeFileSync(outputPath, JSON.stringify(json.abi, null, 2));
  console.log(`Extracted ABI for ${name}`);
});

console.log('All ABIs extracted successfully!');
