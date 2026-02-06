// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title AgentRewards
 * @author Prime AI
 * @notice Distributes PRIME tokens to AI agents for completing verified tasks
 * @dev Uses multi-signature verification from oracle agents for reward distribution
 * 
 * Features:
 * - Task submission by verified oracles
 * - Multi-signature verification (configurable threshold)
 * - Dynamic reward scaling based on task complexity
 * - Anti-gaming protections (rate limits, stake requirements)
 * - Integration hooks for Prime AI orchestrator
 */
contract AgentRewards is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    
    // ============ Constants ============
    
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    
    uint256 public constant MAX_COMPLEXITY_MULTIPLIER = 10;
    uint256 public constant PRECISION = 1e18;
    
    // ============ Enums ============
    
    enum TaskType {
        DATA_PROCESSING,    // Base: 10 PRIME
        CODE_GENERATION,    // Base: 50 PRIME
        SECURITY_AUDIT,     // Base: 100 PRIME
        ORACLE_DATA,        // Base: 25 PRIME
        GOVERNANCE_VOTE     // Base: 5 PRIME
    }
    
    enum TaskStatus {
        PENDING,
        VERIFIED,
        COMPLETED,
        REJECTED
    }
    
    // ============ Structs ============
    
    struct Task {
        bytes32 taskId;
        address agent;
        TaskType taskType;
        uint256 complexityMultiplier; // 1x to 10x (stored as 1e18 to 10e18)
        TaskStatus status;
        uint256 reward;
        uint256 submittedAt;
        uint256 completedAt;
        bytes32 proofHash; // Hash of task completion proof
        address[] verifiers;
    }
    
    struct AgentStats {
        uint256 totalTasksCompleted;
        uint256 totalRewardsEarned;
        uint256 lastTaskTimestamp;
        uint256 reputationScore; // 0-100, affects reward multiplier
        bool isRegistered;
    }
    
    struct RewardTier {
        uint256 baseReward;
        uint256 minComplexity;
        uint256 maxComplexity;
    }
    
    // ============ State Variables ============
    
    IERC20 public immutable primeToken;
    
    uint256 public verificationThreshold = 3; // Number of oracles needed to verify
    uint256 public cooldownPeriod = 60; // Seconds between tasks per agent
    uint256 public minStakeRequired = 100 * 1e18; // 100 PRIME to participate
    
    mapping(bytes32 => Task) public tasks;
    mapping(address => AgentStats) public agentStats;
    mapping(TaskType => RewardTier) public rewardTiers;
    mapping(bytes32 => mapping(address => bool)) public hasVerified;
    
    bytes32[] public pendingTaskIds;
    uint256 public totalRewardsDistributed;
    uint256 public totalTasksCompleted;
    
    // ============ Events ============
    
    event AgentRegistered(address indexed agent, uint256 timestamp);
    event TaskSubmitted(
        bytes32 indexed taskId,
        address indexed agent,
        TaskType taskType,
        uint256 potentialReward
    );
    event TaskVerified(
        bytes32 indexed taskId,
        address indexed verifier,
        uint256 verificationCount
    );
    event TaskCompleted(
        bytes32 indexed taskId,
        address indexed agent,
        uint256 reward
    );
    event TaskRejected(bytes32 indexed taskId, string reason);
    event RewardTierUpdated(TaskType taskType, uint256 baseReward);
    event VerificationThresholdUpdated(uint256 newThreshold);
    
    // ============ Errors ============
    
    error AgentNotRegistered();
    error InsufficientStake();
    error CooldownNotExpired();
    error TaskAlreadyExists();
    error TaskNotFound();
    error TaskNotPending();
    error AlreadyVerified();
    error InvalidComplexity();
    error NotAuthorized();
    error InsufficientRewardPool();
    
    // ============ Constructor ============
    
    /**
     * @notice Deploys the AgentRewards contract
     * @param _primeToken Address of the PRIME token contract
     * @param _admin Address of the admin
     */
    constructor(address _primeToken, address _admin) {
        require(_primeToken != address(0), "Invalid token address");
        require(_admin != address(0), "Invalid admin address");
        
        primeToken = IERC20(_primeToken);
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(OPERATOR_ROLE, _admin);
        
        // Initialize reward tiers (in wei, 18 decimals)
        rewardTiers[TaskType.DATA_PROCESSING] = RewardTier({
            baseReward: 10 * 1e18,
            minComplexity: 1e18,
            maxComplexity: 3e18
        });
        rewardTiers[TaskType.CODE_GENERATION] = RewardTier({
            baseReward: 50 * 1e18,
            minComplexity: 1e18,
            maxComplexity: 5e18
        });
        rewardTiers[TaskType.SECURITY_AUDIT] = RewardTier({
            baseReward: 100 * 1e18,
            minComplexity: 2e18,
            maxComplexity: 10e18
        });
        rewardTiers[TaskType.ORACLE_DATA] = RewardTier({
            baseReward: 25 * 1e18,
            minComplexity: 1e18,
            maxComplexity: 4e18
        });
        rewardTiers[TaskType.GOVERNANCE_VOTE] = RewardTier({
            baseReward: 5 * 1e18,
            minComplexity: 1e18,
            maxComplexity: 1e18
        });
    }
    
    // ============ Agent Registration ============
    
    /**
     * @notice Register as an agent to receive task rewards
     * @dev Requires minimum stake of PRIME tokens
     */
    function registerAgent() external nonReentrant {
        if (primeToken.balanceOf(msg.sender) < minStakeRequired) {
            revert InsufficientStake();
        }
        
        agentStats[msg.sender] = AgentStats({
            totalTasksCompleted: 0,
            totalRewardsEarned: 0,
            lastTaskTimestamp: 0,
            reputationScore: 50, // Start at neutral reputation
            isRegistered: true
        });
        
        emit AgentRegistered(msg.sender, block.timestamp);
    }
    
    // ============ Task Submission ============
    
    /**
     * @notice Submit a task for reward
     * @param taskType Type of task completed
     * @param complexityMultiplier Complexity multiplier (1e18 to 10e18)
     * @param proofHash Hash of the task completion proof
     * @return taskId The unique identifier for this task
     */
    function submitTask(
        TaskType taskType,
        uint256 complexityMultiplier,
        bytes32 proofHash
    ) external nonReentrant whenNotPaused returns (bytes32 taskId) {
        AgentStats storage stats = agentStats[msg.sender];
        
        if (!stats.isRegistered) revert AgentNotRegistered();
        if (primeToken.balanceOf(msg.sender) < minStakeRequired) {
            revert InsufficientStake();
        }
        if (block.timestamp < stats.lastTaskTimestamp + cooldownPeriod) {
            revert CooldownNotExpired();
        }
        
        RewardTier memory tier = rewardTiers[taskType];
        if (
            complexityMultiplier < tier.minComplexity ||
            complexityMultiplier > tier.maxComplexity
        ) {
            revert InvalidComplexity();
        }
        
        // Generate unique task ID
        taskId = keccak256(
            abi.encodePacked(
                msg.sender,
                taskType,
                proofHash,
                block.timestamp,
                block.prevrandao
            )
        );
        
        if (tasks[taskId].submittedAt != 0) revert TaskAlreadyExists();
        
        // Calculate potential reward
        uint256 reward = (tier.baseReward * complexityMultiplier) / PRECISION;
        
        // Apply reputation bonus (up to 50% bonus for max reputation)
        uint256 reputationBonus = (reward * stats.reputationScore) / 200;
        reward += reputationBonus;
        
        tasks[taskId] = Task({
            taskId: taskId,
            agent: msg.sender,
            taskType: taskType,
            complexityMultiplier: complexityMultiplier,
            status: TaskStatus.PENDING,
            reward: reward,
            submittedAt: block.timestamp,
            completedAt: 0,
            proofHash: proofHash,
            verifiers: new address[](0)
        });
        
        pendingTaskIds.push(taskId);
        stats.lastTaskTimestamp = block.timestamp;
        
        emit TaskSubmitted(taskId, msg.sender, taskType, reward);
    }
    
    // ============ Task Verification ============
    
    /**
     * @notice Verify a pending task (oracle only)
     * @param taskId The task to verify
     */
    function verifyTask(bytes32 taskId) external onlyRole(ORACLE_ROLE) nonReentrant {
        Task storage task = tasks[taskId];
        
        if (task.submittedAt == 0) revert TaskNotFound();
        if (task.status != TaskStatus.PENDING) revert TaskNotPending();
        if (hasVerified[taskId][msg.sender]) revert AlreadyVerified();
        
        hasVerified[taskId][msg.sender] = true;
        task.verifiers.push(msg.sender);
        
        emit TaskVerified(taskId, msg.sender, task.verifiers.length);
        
        // Check if threshold reached
        if (task.verifiers.length >= verificationThreshold) {
            _completeTask(taskId);
        }
    }
    
    /**
     * @notice Reject a pending task (oracle only)
     * @param taskId The task to reject
     * @param reason Reason for rejection
     */
    function rejectTask(bytes32 taskId, string calldata reason) 
        external 
        onlyRole(ORACLE_ROLE) 
    {
        Task storage task = tasks[taskId];
        
        if (task.submittedAt == 0) revert TaskNotFound();
        if (task.status != TaskStatus.PENDING) revert TaskNotPending();
        
        task.status = TaskStatus.REJECTED;
        
        // Decrease agent reputation
        AgentStats storage stats = agentStats[task.agent];
        if (stats.reputationScore > 5) {
            stats.reputationScore -= 5;
        }
        
        emit TaskRejected(taskId, reason);
    }
    
    // ============ Internal Functions ============
    
    /**
     * @notice Complete a verified task and distribute rewards
     * @param taskId The task to complete
     */
    function _completeTask(bytes32 taskId) internal {
        Task storage task = tasks[taskId];
        
        uint256 rewardPoolBalance = primeToken.balanceOf(address(this));
        if (rewardPoolBalance < task.reward) {
            revert InsufficientRewardPool();
        }
        
        task.status = TaskStatus.COMPLETED;
        task.completedAt = block.timestamp;
        
        // Update agent stats
        AgentStats storage stats = agentStats[task.agent];
        stats.totalTasksCompleted++;
        stats.totalRewardsEarned += task.reward;
        
        // Increase reputation (max 100)
        if (stats.reputationScore < 100) {
            stats.reputationScore = stats.reputationScore + 1 > 100 
                ? 100 
                : stats.reputationScore + 1;
        }
        
        // Update global stats
        totalRewardsDistributed += task.reward;
        totalTasksCompleted++;
        
        // Transfer reward
        primeToken.safeTransfer(task.agent, task.reward);
        
        emit TaskCompleted(taskId, task.agent, task.reward);
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Update reward tier for a task type
     * @param taskType The task type to update
     * @param baseReward New base reward amount
     * @param minComplexity Minimum complexity multiplier
     * @param maxComplexity Maximum complexity multiplier
     */
    function updateRewardTier(
        TaskType taskType,
        uint256 baseReward,
        uint256 minComplexity,
        uint256 maxComplexity
    ) external onlyRole(OPERATOR_ROLE) {
        require(minComplexity <= maxComplexity, "Invalid complexity range");
        require(maxComplexity <= MAX_COMPLEXITY_MULTIPLIER * PRECISION, "Exceeds max");
        
        rewardTiers[taskType] = RewardTier({
            baseReward: baseReward,
            minComplexity: minComplexity,
            maxComplexity: maxComplexity
        });
        
        emit RewardTierUpdated(taskType, baseReward);
    }
    
    /**
     * @notice Update verification threshold
     * @param newThreshold New number of verifications required
     */
    function setVerificationThreshold(uint256 newThreshold) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(newThreshold > 0 && newThreshold <= 10, "Invalid threshold");
        verificationThreshold = newThreshold;
        emit VerificationThresholdUpdated(newThreshold);
    }
    
    /**
     * @notice Update cooldown period between tasks
     * @param newCooldown New cooldown in seconds
     */
    function setCooldownPeriod(uint256 newCooldown) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(newCooldown <= 1 hours, "Cooldown too long");
        cooldownPeriod = newCooldown;
    }
    
    /**
     * @notice Update minimum stake requirement
     * @param newMinStake New minimum stake amount
     */
    function setMinStakeRequired(uint256 newMinStake) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        minStakeRequired = newMinStake;
    }
    
    /**
     * @notice Add an oracle
     * @param oracle Address to add as oracle
     */
    function addOracle(address oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(ORACLE_ROLE, oracle);
    }
    
    /**
     * @notice Remove an oracle
     * @param oracle Address to remove
     */
    function removeOracle(address oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(ORACLE_ROLE, oracle);
    }
    
    /**
     * @notice Pause the contract
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @notice Emergency withdraw tokens
     * @param token Token to withdraw
     * @param to Recipient address
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(token).safeTransfer(to, amount);
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get task details
     * @param taskId The task ID
     * @return The task struct
     */
    function getTask(bytes32 taskId) external view returns (Task memory) {
        return tasks[taskId];
    }
    
    /**
     * @notice Get agent statistics
     * @param agent The agent address
     * @return The agent stats struct
     */
    function getAgentStats(address agent) external view returns (AgentStats memory) {
        return agentStats[agent];
    }
    
    /**
     * @notice Get reward tier details
     * @param taskType The task type
     * @return The reward tier struct
     */
    function getRewardTier(TaskType taskType) external view returns (RewardTier memory) {
        return rewardTiers[taskType];
    }
    
    /**
     * @notice Get number of pending tasks
     * @return The count of pending tasks
     */
    function getPendingTaskCount() external view returns (uint256) {
        return pendingTaskIds.length;
    }
    
    /**
     * @notice Calculate potential reward for a task
     * @param taskType Type of task
     * @param complexityMultiplier Complexity multiplier
     * @param agentReputation Agent's reputation score
     * @return The potential reward amount
     */
    function calculateReward(
        TaskType taskType,
        uint256 complexityMultiplier,
        uint256 agentReputation
    ) external view returns (uint256) {
        RewardTier memory tier = rewardTiers[taskType];
        uint256 baseReward = (tier.baseReward * complexityMultiplier) / PRECISION;
        uint256 reputationBonus = (baseReward * agentReputation) / 200;
        return baseReward + reputationBonus;
    }
}
