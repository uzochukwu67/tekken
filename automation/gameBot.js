import { ethers } from 'ethers';
import dotenv from 'dotenv';
import { logger, sendDiscordAlert } from './logger.js';
import fs from 'fs';

// Load environment variables
dotenv.config();

// Configuration
const config = {
  rpcUrl: process.env.SEPOLIA_RPC_URL,
  privateKey: process.env.PRIVATE_KEY,
  gameEngineAddress: process.env.GAME_ENGINE_ADDRESS,
  roundDurationMinutes: parseInt(process.env.ROUND_DURATION_MINUTES || '15'),
  checkIntervalSeconds: parseInt(process.env.CHECK_INTERVAL_SECONDS || '30'),
  autoStartSeason: process.env.AUTO_START_SEASON === 'true',
  maxGasPriceGwei: process.env.MAX_GAS_PRICE_GWEI || '50',
  gasLimitStartRound: process.env.GAS_LIMIT_START_ROUND || '250000',
  gasLimitRequestVRF: process.env.GAS_LIMIT_REQUEST_VRF || '150000',
};

// GameEngine ABI (minimal interface needed)
const GAME_ENGINE_ABI = [
  'function getCurrentSeason() external view returns (uint256)',
  'function getCurrentRound() external view returns (uint256)',
  'function isRoundSettled(uint256 roundId) external view returns (bool)',
  'function getRound(uint256 roundId) external view returns (tuple(uint256 roundId, uint256 seasonId, uint256 startTime, uint256 vrfRequestId, bool settled))',
  'function getSeason(uint256 seasonId) external view returns (tuple(uint256 seasonId, uint256 startTime, uint256 currentRound, bool active, bool completed, uint256 winningTeamId))',
  'function startSeason() external',
  'function startRound() external',
  'function requestMatchResults() external',
  'function ROUND_DURATION() external view returns (uint256)',
  'function ROUNDS_PER_SEASON() external view returns (uint256)',
  'event SeasonStarted(uint256 indexed seasonId, uint256 startTime)',
  'event SeasonEnded(uint256 indexed seasonId, uint256 winningTeamId)',
  'event RoundStarted(uint256 indexed roundId, uint256 indexed seasonId, uint256 startTime)',
  'event RoundSettled(uint256 indexed roundId, uint256 indexed seasonId)',
  'event VRFRequested(uint256 indexed roundId, uint256 requestId)',
];

// Global state
let provider;
let wallet;
let gameEngine;
let botState = {
  currentRound: 0,
  currentSeason: 0,
  roundStartTime: 0,
  isProcessing: false,
  lastChecked: 0,
  vrfRequestPending: false,
};

// Initialize connection
async function initialize() {
  logger.info('🤖 Starting iVirtualz Game Automation Bot...');

  // Validate config
  if (!config.rpcUrl || !config.privateKey || !config.gameEngineAddress) {
    logger.error('❌ Missing required environment variables. Check .env file.');
    process.exit(1);
  }

  // Create logs directory
  if (!fs.existsSync('logs')) {
    fs.mkdirSync('logs');
  }

  try {
    // Connect to provider
    provider = new ethers.JsonRpcProvider(config.rpcUrl);
    logger.info(`✅ Connected to RPC: ${config.rpcUrl}`);

    // Create wallet
    wallet = new ethers.Wallet(config.privateKey, provider);
    const walletAddress = await wallet.getAddress();
    logger.info(`✅ Wallet: ${walletAddress}`);

    // Check wallet balance
    const balance = await provider.getBalance(walletAddress);
    const balanceEth = ethers.formatEther(balance);
    logger.info(`💰 Balance: ${balanceEth} ETH`);

    if (parseFloat(balanceEth) < 0.01) {
      logger.warn(`⚠️  Low balance! Get Sepolia ETH from: https://sepoliafaucet.com`);
    }

    // Connect to GameEngine
    gameEngine = new ethers.Contract(config.gameEngineAddress, GAME_ENGINE_ABI, wallet);
    logger.info(`✅ Connected to GameEngine: ${config.gameEngineAddress}`);

    // Get contract constants
    const roundDuration = await gameEngine.ROUND_DURATION();
    const roundsPerSeason = await gameEngine.ROUNDS_PER_SEASON();
    logger.info(`📊 Round Duration: ${roundDuration} seconds (${roundDuration / 60n} minutes)`);
    logger.info(`📊 Rounds Per Season: ${roundsPerSeason}`);

    // Sync state
    await syncState();

    logger.info('✅ Bot initialized successfully!');
    logger.info(`🔄 Checking every ${config.checkIntervalSeconds} seconds`);
    logger.info('');

    await sendDiscordAlert('✅ Game Bot started successfully', 'success');

  } catch (error) {
    logger.error(`❌ Initialization failed: ${error.message}`);
    process.exit(1);
  }
}

// Sync current state from contract
async function syncState() {
  try {
    botState.currentSeason = Number(await gameEngine.getCurrentSeason());
    botState.currentRound = Number(await gameEngine.getCurrentRound());

    logger.info(`📍 Current Season: ${botState.currentSeason}`);
    logger.info(`📍 Current Round: ${botState.currentRound}`);

    if (botState.currentRound > 0) {
      const round = await gameEngine.getRound(botState.currentRound);
      botState.roundStartTime = Number(round.startTime);
      const settled = await gameEngine.isRoundSettled(botState.currentRound);

      logger.info(`📍 Round ${botState.currentRound} started at: ${new Date(botState.roundStartTime * 1000).toLocaleString()}`);
      logger.info(`📍 Round ${botState.currentRound} settled: ${settled}`);
    }

    if (botState.currentSeason > 0) {
      const season = await gameEngine.getSeason(botState.currentSeason);
      logger.info(`📍 Season ${botState.currentSeason} active: ${season.active}`);
      logger.info(`📍 Season ${botState.currentSeason} completed: ${season.completed}`);
    }

  } catch (error) {
    logger.error(`Failed to sync state: ${error.message}`);
  }
}

// Start a new season
async function startSeason() {
  logger.info('🎯 Starting new season...');

  try {
    const tx = await gameEngine.startSeason({
      gasLimit: config.gasLimitStartRound,
    });

    logger.info(`📤 Transaction sent: ${tx.hash}`);
    const receipt = await tx.wait();
    logger.info(`✅ Season started! Gas used: ${receipt.gasUsed.toString()}`);

    await syncState();
    await sendDiscordAlert(`🎯 Season ${botState.currentSeason} started!`, 'success');

  } catch (error) {
    logger.error(`❌ Failed to start season: ${error.message}`);
    if (error.message.includes('Season already active')) {
      logger.info('ℹ️  Season already active, continuing...');
    }
  }
}

// Start a new round
async function startRound() {
  logger.info(`🏁 Starting round ${botState.currentRound + 1}...`);

  try {
    const tx = await gameEngine.startRound({
      gasLimit: config.gasLimitStartRound,
    });

    logger.info(`📤 Transaction sent: ${tx.hash}`);
    const receipt = await tx.wait();
    logger.info(`✅ Round started! Gas used: ${receipt.gasUsed.toString()}`);

    await syncState();
    await sendDiscordAlert(`🏁 Round ${botState.currentRound} started`, 'info');

  } catch (error) {
    logger.error(`❌ Failed to start round: ${error.message}`);
    throw error;
  }
}

// Request VRF for match results
async function requestVRF() {
  logger.info(`🎲 Requesting VRF for round ${botState.currentRound}...`);

  try {
    const tx = await gameEngine.requestMatchResults({
      gasLimit: config.gasLimitRequestVRF,
    });

    logger.info(`📤 Transaction sent: ${tx.hash}`);
    const receipt = await tx.wait();
    logger.info(`✅ VRF requested! Gas used: ${receipt.gasUsed.toString()}`);
    logger.info(`⏳ Waiting for Chainlink VRF to fulfill (1-5 minutes)...`);

    botState.vrfRequestPending = true;
    await sendDiscordAlert(`🎲 VRF requested for round ${botState.currentRound}`, 'info');

  } catch (error) {
    logger.error(`❌ Failed to request VRF: ${error.message}`);
    if (error.message.includes('Round duration not elapsed')) {
      logger.info('ℹ️  Round duration not elapsed yet, will retry...');
    }
    throw error;
  }
}

// Main game loop logic
async function checkAndExecute() {
  if (botState.isProcessing) {
    return; // Skip if already processing
  }

  botState.isProcessing = true;

  try {
    const now = Math.floor(Date.now() / 1000);

    // Refresh state
    const currentSeason = Number(await gameEngine.getCurrentSeason());
    const currentRound = Number(await gameEngine.getCurrentRound());

    // Check if we need to start a season
    if (currentSeason === 0 && config.autoStartSeason) {
      logger.info('🎯 No active season detected, starting new season...');
      await startSeason();
      botState.isProcessing = false;
      return;
    }

    // Check if season is completed
    if (currentSeason > 0) {
      const season = await gameEngine.getSeason(currentSeason);

      if (season.completed && config.autoStartSeason) {
        logger.info(`🏆 Season ${currentSeason} completed! Winner: Team #${season.winningTeamId}`);
        await sendDiscordAlert(`🏆 Season ${currentSeason} completed! Winner: Team #${season.winningTeamId}`, 'success');
        logger.info('🎯 Starting new season...');
        await startSeason();
        botState.isProcessing = false;
        return;
      }
    }

    // Handle round lifecycle
    if (currentRound === 0) {
      // No round yet, start first round
      logger.info('🏁 No round detected, starting first round...');
      await startRound();

    } else {
      // Check if current round is settled
      const isSettled = await gameEngine.isRoundSettled(currentRound);

      if (isSettled) {
        // Round is settled, start next round
        logger.info(`✅ Round ${currentRound} settled successfully`);

        if (botState.vrfRequestPending) {
          botState.vrfRequestPending = false;
          await sendDiscordAlert(`✅ Round ${currentRound} settled by VRF`, 'success');
        }

        // Check if season is complete
        const season = await gameEngine.getSeason(currentSeason);
        if (season.currentRound >= 36n) {
          logger.info(`🏆 Season ${currentSeason} complete! All 36 rounds finished.`);
          // Season will auto-complete, bot will start new season on next check
        } else {
          logger.info(`🔄 Starting next round (${Number(season.currentRound) + 1}/36)...`);
          await new Promise(resolve => setTimeout(resolve, 5000)); // Wait 5 seconds
          await startRound();
        }

      } else {
        // Round not settled yet, check if we need to request VRF
        const round = await gameEngine.getRound(currentRound);
        const roundStartTime = Number(round.startTime);
        const elapsed = now - roundStartTime;
        const roundDurationSeconds = config.roundDurationMinutes * 60;

        if (round.vrfRequestId === 0n && elapsed >= roundDurationSeconds) {
          // Round duration passed and VRF not requested yet
          logger.info(`⏰ Round ${currentRound} duration elapsed (${elapsed}s), requesting VRF...`);
          await requestVRF();

        } else if (round.vrfRequestId > 0n) {
          // VRF already requested, waiting for fulfillment
          const waitTime = now - roundStartTime;
          logger.info(`⏳ Waiting for VRF fulfillment... (${Math.floor(waitTime / 60)} min ${waitTime % 60} sec)`);

          // Warn if VRF taking too long (>10 minutes)
          if (waitTime > 600 && !botState.vrfRequestPending) {
            logger.warn(`⚠️  VRF taking longer than expected (${Math.floor(waitTime / 60)} minutes)`);
            botState.vrfRequestPending = true;
          }

        } else {
          // Still waiting for round duration
          const remaining = roundDurationSeconds - elapsed;
          logger.info(`⏰ Waiting for round duration: ${Math.floor(remaining / 60)} min ${remaining % 60} sec remaining`);
        }
      }
    }

    botState.lastChecked = now;

  } catch (error) {
    logger.error(`❌ Error in game loop: ${error.message}`);
    await sendDiscordAlert(`❌ Bot error: ${error.message}`, 'error');
  } finally {
    botState.isProcessing = false;
  }
}

// Start the bot
async function start() {
  await initialize();

  // Run check loop
  setInterval(async () => {
    await checkAndExecute();
  }, config.checkIntervalSeconds * 1000);

  // Run immediately on start
  await checkAndExecute();
}

// Handle graceful shutdown
process.on('SIGINT', async () => {
  logger.info('\n🛑 Shutting down gracefully...');
  await sendDiscordAlert('🛑 Game Bot shutting down', 'warning');
  process.exit(0);
});

process.on('SIGTERM', async () => {
  logger.info('\n🛑 Shutting down gracefully...');
  await sendDiscordAlert('🛑 Game Bot shutting down', 'warning');
  process.exit(0);
});

// Start the bot
start().catch((error) => {
  logger.error(`💥 Fatal error: ${error.message}`);
  process.exit(1);
});
