// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IPrimeToken
 * @notice Interface for the PrimeToken contract
 */
interface IPrimeToken is IERC20 {
    function pause() external;
    function unpause() external;
    function initialize(
        address _agentRewards,
        address _treasury,
        address _teamVesting,
        address _community,
        address _liquidity,
        address _advisorsVesting
    ) external;
    function setAgentRewardsContract(address newAgentRewards) external;
    function circulatingSupply() external view returns (uint256);
}

/**
 * @title IAgentRewards
 * @notice Interface for the AgentRewards contract
 */
interface IAgentRewards {
    enum TaskType {
        DATA_PROCESSING,
        CODE_GENERATION,
        SECURITY_AUDIT,
        ORACLE_DATA,
        GOVERNANCE_VOTE
    }
    
    function registerAgent() external;
    function submitTask(
        TaskType taskType,
        uint256 complexityMultiplier,
        bytes32 proofHash
    ) external returns (bytes32 taskId);
    function verifyTask(bytes32 taskId) external;
    function rejectTask(bytes32 taskId, string calldata reason) external;
    function calculateReward(
        TaskType taskType,
        uint256 complexityMultiplier,
        uint256 agentReputation
    ) external view returns (uint256);
}

/**
 * @title IStaking
 * @notice Interface for the Staking contract
 */
interface IStaking {
    function stake(uint256 amount, uint256 lockDuration) external;
    function addToStake(uint256 amount) external;
    function unstake() external;
    function claimRewards() external;
    function delegate(address delegatee) external;
    function getVotingPower(address user) external view returns (uint256);
    function pendingRewards(address user) external view returns (uint256);
    function canUnstake(address user) external view returns (bool);
}

/**
 * @title ITreasury
 * @notice Interface for the Treasury contract
 */
interface ITreasury {
    function createProposal(
        address recipient,
        uint256 amount,
        string calldata description
    ) external returns (uint256);
    function vote(uint256 proposalId, bool support) external;
    function executeProposal(uint256 proposalId) external;
    function releaseVestedTokens() external;
    function releasableAmount(address beneficiary) external view returns (uint256);
    function treasuryBalance() external view returns (uint256);
}
