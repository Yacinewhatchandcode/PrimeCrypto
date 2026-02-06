/**
 * PrimeCrypto Bridge - Agent-to-Chain Oracle
 * 
 * Connects Prime AI agents to the blockchain for task verification
 * and reward distribution.
 */

import { ethers, Contract, Wallet, JsonRpcProvider } from 'ethers';
import { createLogger, format, transports } from 'winston';
import * as dotenv from 'dotenv';

dotenv.config();

// ============ Types ============

export enum TaskType {
    DATA_PROCESSING = 0,
    CODE_GENERATION = 1,
    SECURITY_AUDIT = 2,
    ORACLE_DATA = 3,
    GOVERNANCE_VOTE = 4
}

export interface TaskVerification {
    taskId: string;
    agentAddress: string;
    taskType: TaskType;
    complexityMultiplier: bigint;
    proofHash: string;
    score: number; // 0-100 quality score
}

export interface OracleConfig {
    privateKey: string;
    rpcUrl: string;
    agentRewardsAddress: string;
    verificationThreshold: number;
}

// ============ Logger ============

const logger = createLogger({
    level: 'info',
    format: format.combine(
        format.timestamp(),
        format.colorize(),
        format.printf(({ timestamp, level, message }) => {
            return `${timestamp} [Oracle] ${level}: ${message}`;
        })
    ),
    transports: [
        new transports.Console(),
        new transports.File({ filename: 'oracle.log' })
    ]
});

// ============ ABI ============

const AGENT_REWARDS_ABI = [
    "function verifyTask(bytes32 taskId) external",
    "function rejectTask(bytes32 taskId, string reason) external",
    "function getTask(bytes32 taskId) external view returns (tuple(bytes32 taskId, address agent, uint8 taskType, uint256 complexityMultiplier, uint8 status, uint256 reward, uint256 submittedAt, uint256 completedAt, bytes32 proofHash, address[] verifiers))",
    "function hasVerified(bytes32 taskId, address oracle) external view returns (bool)",
    "event TaskSubmitted(bytes32 indexed taskId, address indexed agent, uint8 taskType, uint256 potentialReward)",
    "event TaskVerified(bytes32 indexed taskId, address indexed verifier, uint256 verificationCount)",
    "event TaskCompleted(bytes32 indexed taskId, address indexed agent, uint256 reward)"
];

// ============ Oracle Class ============

export class TaskOracle {
    private provider: JsonRpcProvider;
    private wallet: Wallet;
    private contract: Contract;
    private pendingVerifications: Map<string, TaskVerification[]> = new Map();

    constructor(config: OracleConfig) {
        this.provider = new JsonRpcProvider(config.rpcUrl);
        this.wallet = new Wallet(config.privateKey, this.provider);
        this.contract = new Contract(
            config.agentRewardsAddress,
            AGENT_REWARDS_ABI,
            this.wallet
        );

        logger.info(`Oracle initialized: ${this.wallet.address}`);
    }

    /**
     * Start listening for task submissions
     */
    async start(): Promise<void> {
        logger.info('Starting oracle service...');

        // Listen for TaskSubmitted events
        this.contract.on('TaskSubmitted', async (taskId, agent, taskType, reward) => {
            logger.info(`New task submitted: ${taskId} by ${agent}`);
            await this.processTask(taskId);
        });

        // Listen for TaskCompleted events
        this.contract.on('TaskCompleted', async (taskId, agent, reward) => {
            logger.info(`Task completed: ${taskId}, reward: ${ethers.formatEther(reward)} PRIME`);
        });

        logger.info('Oracle service started');
    }

    /**
     * Process a submitted task
     */
    async processTask(taskId: string): Promise<void> {
        try {
            // Check if already verified by this oracle
            const hasVerified = await this.contract.hasVerified(taskId, this.wallet.address);
            if (hasVerified) {
                logger.info(`Already verified task: ${taskId}`);
                return;
            }

            // Get task details
            const task = await this.contract.getTask(taskId);

            // Validate the task
            const isValid = await this.validateTask({
                taskId,
                agentAddress: task.agent,
                taskType: task.taskType,
                complexityMultiplier: task.complexityMultiplier,
                proofHash: task.proofHash,
                score: 0 // Will be calculated
            });

            if (isValid) {
                await this.verifyTask(taskId);
            } else {
                await this.rejectTask(taskId, 'Failed validation checks');
            }
        } catch (error) {
            logger.error(`Error processing task ${taskId}: ${error}`);
        }
    }

    /**
     * Validate a task based on proof and complexity
     */
    async validateTask(verification: TaskVerification): Promise<boolean> {
        logger.info(`Validating task: ${verification.taskId}`);

        // In production, this would:
        // 1. Fetch the actual task proof from IPFS or storage
        // 2. Verify the proof matches the hash
        // 3. Assess the quality of the work
        // 4. Check for plagiarism/gaming

        // For now, simple validation
        const validations = [
            // Check proof hash is not empty
            verification.proofHash !== ethers.ZeroHash,

            // Check complexity is within bounds
            verification.complexityMultiplier >= ethers.parseEther('1') &&
            verification.complexityMultiplier <= ethers.parseEther('10'),

            // More validation logic would go here
        ];

        const isValid = validations.every(v => v);
        logger.info(`Task ${verification.taskId} validation: ${isValid ? 'PASSED' : 'FAILED'}`);

        return isValid;
    }

    /**
     * Submit verification for a task
     */
    async verifyTask(taskId: string): Promise<void> {
        try {
            logger.info(`Verifying task: ${taskId}`);

            const tx = await this.contract.verifyTask(taskId);
            const receipt = await tx.wait();

            logger.info(`Verification submitted: ${receipt.hash}`);
        } catch (error) {
            logger.error(`Error verifying task: ${error}`);
            throw error;
        }
    }

    /**
     * Reject a task with reason
     */
    async rejectTask(taskId: string, reason: string): Promise<void> {
        try {
            logger.info(`Rejecting task: ${taskId} - ${reason}`);

            const tx = await this.contract.rejectTask(taskId, reason);
            await tx.wait();

            logger.info(`Task rejected: ${taskId}`);
        } catch (error) {
            logger.error(`Error rejecting task: ${error}`);
            throw error;
        }
    }

    /**
     * Get oracle status
     */
    async getStatus(): Promise<{
        address: string;
        balance: string;
        connected: boolean;
    }> {
        const balance = await this.provider.getBalance(this.wallet.address);
        return {
            address: this.wallet.address,
            balance: ethers.formatEther(balance),
            connected: true
        };
    }

    /**
     * Stop the oracle
     */
    stop(): void {
        this.contract.removeAllListeners();
        logger.info('Oracle service stopped');
    }
}

// ============ Main ============

async function main() {
    const config: OracleConfig = {
        privateKey: process.env.ORACLE_PRIVATE_KEY || '',
        rpcUrl: process.env.RPC_URL || 'https://sepolia.base.org',
        agentRewardsAddress: process.env.AGENT_REWARDS_ADDRESS || '',
        verificationThreshold: 3
    };

    if (!config.privateKey || !config.agentRewardsAddress) {
        console.error('Missing required environment variables');
        console.error('Set: ORACLE_PRIVATE_KEY, AGENT_REWARDS_ADDRESS');
        process.exit(1);
    }

    const oracle = new TaskOracle(config);
    await oracle.start();

    // Keep running
    process.on('SIGINT', () => {
        oracle.stop();
        process.exit(0);
    });
}

// Run if executed directly
if (require.main === module) {
    main().catch(console.error);
}

export default TaskOracle;
