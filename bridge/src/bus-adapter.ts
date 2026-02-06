/**
 * PrimeCrypto Bridge - Prime AI Message Bus Adapter
 * 
 * Connects to the Prime AI orchestrator's message bus to receive
 * task completion events and translate them into blockchain transactions.
 */

import WebSocket from 'ws';
import { ethers } from 'ethers';
import { createLogger, format, transports } from 'winston';
import * as dotenv from 'dotenv';
import TaskOracle, { TaskType } from './oracle';

dotenv.config();

// ============ Types ============

interface BusMessage {
    type: string;
    payload: any;
    timestamp: number;
    source: string;
}

interface AgentTaskComplete {
    agentId: string;
    taskId: string;
    taskType: string;
    result: any;
    metrics: {
        duration: number;
        complexity: number;
        quality: number;
    };
}

interface BusAdapterConfig {
    busUrl: string;
    oracle: TaskOracle;
    agentRewardsAddress: string;
    reconnectInterval: number;
}

// ============ Logger ============

const logger = createLogger({
    level: 'info',
    format: format.combine(
        format.timestamp(),
        format.colorize(),
        format.printf(({ timestamp, level, message }) => {
            return `${timestamp} [BusAdapter] ${level}: ${message}`;
        })
    ),
    transports: [
        new transports.Console(),
        new transports.File({ filename: 'bus-adapter.log' })
    ]
});

// ============ Task Type Mapping ============

const TASK_TYPE_MAP: Record<string, TaskType> = {
    'data-processing': TaskType.DATA_PROCESSING,
    'code-generation': TaskType.CODE_GENERATION,
    'security-audit': TaskType.SECURITY_AUDIT,
    'oracle-data': TaskType.ORACLE_DATA,
    'governance-vote': TaskType.GOVERNANCE_VOTE,
    // Prime AI agent types
    'CodeAgent': TaskType.CODE_GENERATION,
    'SecurityAgent': TaskType.SECURITY_AUDIT,
    'DataAgent': TaskType.DATA_PROCESSING,
    'ResearchAgent': TaskType.ORACLE_DATA,
};

// ============ Bus Adapter Class ============

export class PrimeAIBusAdapter {
    private ws: WebSocket | null = null;
    private config: BusAdapterConfig;
    private isConnected: boolean = false;
    private reconnectTimer: NodeJS.Timeout | null = null;
    private agentWallets: Map<string, string> = new Map();

    constructor(config: BusAdapterConfig) {
        this.config = config;
        logger.info('Bus adapter initialized');
    }

    /**
     * Connect to the Prime AI message bus
     */
    async connect(): Promise<void> {
        return new Promise((resolve, reject) => {
            logger.info(`Connecting to message bus: ${this.config.busUrl}`);

            this.ws = new WebSocket(this.config.busUrl);

            this.ws.on('open', () => {
                this.isConnected = true;
                logger.info('Connected to Prime AI message bus');

                // Subscribe to agent task events
                this.subscribe(['agent.task.completed', 'agent.task.verified']);
                resolve();
            });

            this.ws.on('message', (data: WebSocket.Data) => {
                try {
                    const message = JSON.parse(data.toString()) as BusMessage;
                    this.handleMessage(message);
                } catch (error) {
                    logger.error(`Failed to parse message: ${error}`);
                }
            });

            this.ws.on('close', () => {
                this.isConnected = false;
                logger.warn('Disconnected from message bus');
                this.scheduleReconnect();
            });

            this.ws.on('error', (error) => {
                logger.error(`WebSocket error: ${error}`);
                reject(error);
            });
        });
    }

    /**
     * Subscribe to message bus topics
     */
    private subscribe(topics: string[]): void {
        if (!this.ws || !this.isConnected) return;

        const message = {
            type: 'subscribe',
            topics
        };

        this.ws.send(JSON.stringify(message));
        logger.info(`Subscribed to topics: ${topics.join(', ')}`);
    }

    /**
     * Handle incoming message from bus
     */
    private async handleMessage(message: BusMessage): Promise<void> {
        logger.debug(`Received message: ${message.type}`);

        switch (message.type) {
            case 'agent.task.completed':
                await this.handleTaskCompleted(message.payload as AgentTaskComplete);
                break;

            case 'agent.task.verified':
                logger.info(`Task verified by Prime AI: ${message.payload.taskId}`);
                break;

            default:
                logger.debug(`Unhandled message type: ${message.type}`);
        }
    }

    /**
     * Handle task completion from Prime AI agent
     */
    private async handleTaskCompleted(task: AgentTaskComplete): Promise<void> {
        logger.info(`Processing task completion: ${task.taskId} from ${task.agentId}`);

        try {
            // Get or create wallet for agent
            const agentWallet = await this.getAgentWallet(task.agentId);

            // Map task type
            const taskType = TASK_TYPE_MAP[task.taskType] ?? TaskType.DATA_PROCESSING;

            // Calculate complexity multiplier (1-10x based on metrics)
            const complexity = this.calculateComplexity(task.metrics);

            // Generate proof hash
            const proofHash = this.generateProofHash(task);

            // Submit task to blockchain
            await this.submitTask(agentWallet, taskType, complexity, proofHash);

            logger.info(`Task ${task.taskId} submitted to blockchain`);
        } catch (error) {
            logger.error(`Failed to process task ${task.taskId}: ${error}`);
        }
    }

    /**
     * Get or derive wallet address for an agent
     */
    private async getAgentWallet(agentId: string): Promise<string> {
        if (this.agentWallets.has(agentId)) {
            return this.agentWallets.get(agentId)!;
        }

        // Derive deterministic wallet from agent ID
        // In production, this would use secure key derivation
        const seed = ethers.keccak256(ethers.toUtf8Bytes(`prime-agent-${agentId}`));
        const wallet = new ethers.Wallet(seed);

        this.agentWallets.set(agentId, wallet.address);
        logger.info(`Derived wallet for agent ${agentId}: ${wallet.address}`);

        return wallet.address;
    }

    /**
     * Calculate complexity multiplier from task metrics
     */
    private calculateComplexity(metrics: AgentTaskComplete['metrics']): bigint {
        // Normalize complexity to 1-10 range
        let multiplier = 1;

        // Factor in task complexity (0-100)
        multiplier += (metrics.complexity / 100) * 4;

        // Factor in quality (0-100)
        multiplier += (metrics.quality / 100) * 3;

        // Factor in duration (longer = more complex, capped)
        const durationBonus = Math.min(metrics.duration / 3600, 2); // Up to 2x for 1 hour+
        multiplier += durationBonus;

        // Clamp to valid range
        multiplier = Math.max(1, Math.min(10, multiplier));

        return ethers.parseEther(multiplier.toFixed(2));
    }

    /**
     * Generate proof hash for task
     */
    private generateProofHash(task: AgentTaskComplete): string {
        const data = ethers.solidityPacked(
            ['string', 'string', 'string', 'uint256'],
            [task.agentId, task.taskId, JSON.stringify(task.result), task.metrics.quality]
        );
        return ethers.keccak256(data);
    }

    /**
     * Submit task to blockchain (via oracle or direct)
     */
    private async submitTask(
        agentAddress: string,
        taskType: TaskType,
        complexity: bigint,
        proofHash: string
    ): Promise<void> {
        // In production, this would either:
        // 1. Have the agent sign and submit directly
        // 2. Use a relay service
        // 3. Queue for batch submission

        logger.info(`Task submission prepared: agent=${agentAddress}, type=${taskType}, complexity=${ethers.formatEther(complexity)}x`);

        // Emit event for oracle to pick up
        // This would typically go through a proper queue/messaging system
    }

    /**
     * Schedule reconnection attempt
     */
    private scheduleReconnect(): void {
        if (this.reconnectTimer) return;

        this.reconnectTimer = setTimeout(async () => {
            this.reconnectTimer = null;
            logger.info('Attempting to reconnect...');

            try {
                await this.connect();
            } catch (error) {
                logger.error(`Reconnection failed: ${error}`);
                this.scheduleReconnect();
            }
        }, this.config.reconnectInterval);
    }

    /**
     * Disconnect from bus
     */
    disconnect(): void {
        if (this.reconnectTimer) {
            clearTimeout(this.reconnectTimer);
            this.reconnectTimer = null;
        }

        if (this.ws) {
            this.ws.close();
            this.ws = null;
        }

        this.isConnected = false;
        logger.info('Disconnected from message bus');
    }

    /**
     * Get adapter status
     */
    getStatus(): {
        connected: boolean;
        agentCount: number;
        busUrl: string;
    } {
        return {
            connected: this.isConnected,
            agentCount: this.agentWallets.size,
            busUrl: this.config.busUrl
        };
    }
}

export default PrimeAIBusAdapter;
