/**
 * PrimeCrypto Bridge - Main Entry Point
 * 
 * Orchestrates the Oracle and Bus Adapter services
 */

import * as dotenv from 'dotenv';
import TaskOracle, { OracleConfig } from './oracle';
import PrimeAIBusAdapter from './bus-adapter';
import { createLogger, format, transports } from 'winston';

dotenv.config();

// ============ Logger ============

const logger = createLogger({
    level: 'info',
    format: format.combine(
        format.timestamp(),
        format.colorize(),
        format.printf(({ timestamp, level, message }) => {
            return `${timestamp} [Bridge] ${level}: ${message}`;
        })
    ),
    transports: [
        new transports.Console(),
        new transports.File({ filename: 'bridge.log' })
    ]
});

// ============ Configuration ============

interface BridgeConfig {
    oracle: OracleConfig;
    bus: {
        url: string;
        reconnectInterval: number;
    };
}

function loadConfig(): BridgeConfig {
    return {
        oracle: {
            privateKey: process.env.ORACLE_PRIVATE_KEY || '',
            rpcUrl: process.env.RPC_URL || 'https://sepolia.base.org',
            agentRewardsAddress: process.env.AGENT_REWARDS_ADDRESS || '',
            verificationThreshold: parseInt(process.env.VERIFICATION_THRESHOLD || '3')
        },
        bus: {
            url: process.env.PRIME_AI_MESSAGE_BUS_URL || 'ws://localhost:3003',
            reconnectInterval: parseInt(process.env.RECONNECT_INTERVAL || '5000')
        }
    };
}

// ============ Main ============

async function main() {
    console.log('');
    console.log('╔════════════════════════════════════════════════════════════╗');
    console.log('║           PRIMECRYPTO BRIDGE SERVICE                       ║');
    console.log('║     Connecting Prime AI Agents to Blockchain               ║');
    console.log('╚════════════════════════════════════════════════════════════╝');
    console.log('');

    const config = loadConfig();

    // Validate configuration
    if (!config.oracle.privateKey) {
        logger.error('Missing ORACLE_PRIVATE_KEY');
        process.exit(1);
    }
    if (!config.oracle.agentRewardsAddress) {
        logger.error('Missing AGENT_REWARDS_ADDRESS');
        process.exit(1);
    }

    // Initialize Oracle
    logger.info('Initializing Oracle service...');
    const oracle = new TaskOracle(config.oracle);

    // Initialize Bus Adapter
    logger.info('Initializing Bus Adapter...');
    const busAdapter = new PrimeAIBusAdapter({
        busUrl: config.bus.url,
        oracle,
        agentRewardsAddress: config.oracle.agentRewardsAddress,
        reconnectInterval: config.bus.reconnectInterval
    });

    // Start services
    try {
        await oracle.start();
        logger.info('Oracle service started');

        // Try to connect to bus (may fail if orchestrator not running)
        try {
            await busAdapter.connect();
            logger.info('Bus adapter connected');
        } catch (error) {
            logger.warn('Could not connect to message bus, running in oracle-only mode');
        }

        // Print status
        const oracleStatus = await oracle.getStatus();
        const busStatus = busAdapter.getStatus();

        console.log('');
        console.log('Service Status:');
        console.log(`  Oracle Address:  ${oracleStatus.address}`);
        console.log(`  Oracle Balance:  ${oracleStatus.balance} ETH`);
        console.log(`  Bus Connected:   ${busStatus.connected}`);
        console.log(`  Contracts:       ${config.oracle.agentRewardsAddress}`);
        console.log('');
        console.log('Bridge is running. Press Ctrl+C to stop.');
        console.log('');

    } catch (error) {
        logger.error(`Failed to start services: ${error}`);
        process.exit(1);
    }

    // Graceful shutdown
    process.on('SIGINT', () => {
        logger.info('Shutting down...');
        oracle.stop();
        busAdapter.disconnect();
        process.exit(0);
    });

    process.on('SIGTERM', () => {
        logger.info('Shutting down...');
        oracle.stop();
        busAdapter.disconnect();
        process.exit(0);
    });
}

main().catch((error) => {
    console.error('Fatal error:', error);
    process.exit(1);
});
