// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title Staking
 * @author Prime AI
 * @notice Stake PRIME tokens to earn rewards and participate in governance
 * @dev Implements time-weighted staking with voting power delegation
 * 
 * Features:
 * - Stake PRIME to earn rewards (10-20% APY based on lock duration)
 * - Voting power proportional to stake and lock time
 * - Delegation support for governance
 * - Slashing for malicious oracle behavior
 */
contract Staking is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    
    // ============ Constants ============
    
    bytes32 public constant SLASHER_ROLE = keccak256("SLASHER_ROLE");
    
    uint256 public constant MIN_STAKE = 10 * 1e18; // 10 PRIME minimum
    uint256 public constant MAX_LOCK_DURATION = 365 days;
    uint256 public constant PRECISION = 1e18;
    
    // APY tiers (in basis points, 100 = 1%)
    uint256 public constant APY_NO_LOCK = 1000;      // 10% APY
    uint256 public constant APY_30_DAYS = 1200;      // 12% APY
    uint256 public constant APY_90_DAYS = 1500;      // 15% APY
    uint256 public constant APY_180_DAYS = 1800;     // 18% APY
    uint256 public constant APY_365_DAYS = 2000;     // 20% APY
    
    // ============ Structs ============
    
    struct StakeInfo {
        uint256 amount;
        uint256 lockEndTime;
        uint256 lockDuration;
        uint256 lastRewardClaim;
        uint256 votingPower;
        address delegate;
    }
    
    struct DelegateInfo {
        uint256 delegatedVotingPower;
        address[] delegators;
    }
    
    // ============ State Variables ============
    
    IERC20 public immutable primeToken;
    
    uint256 public totalStaked;
    uint256 public totalVotingPower;
    uint256 public rewardPool;
    
    mapping(address => StakeInfo) public stakes;
    mapping(address => DelegateInfo) public delegates;
    
    // ============ Events ============
    
    event Staked(
        address indexed user,
        uint256 amount,
        uint256 lockDuration,
        uint256 votingPower
    );
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate,
        uint256 votingPower
    );
    event Slashed(address indexed user, uint256 amount, string reason);
    event RewardPoolFunded(address indexed funder, uint256 amount);
    
    // ============ Errors ============
    
    error InsufficientAmount();
    error StillLocked();
    error NoStakeFound();
    error InvalidLockDuration();
    error AlreadyStaked();
    error CannotSlashMore();
    error ZeroAddress();
    
    // ============ Constructor ============
    
    /**
     * @notice Deploys the Staking contract
     * @param _primeToken Address of the PRIME token contract
     * @param _admin Address of the admin
     */
    constructor(address _primeToken, address _admin) {
        require(_primeToken != address(0), "Invalid token");
        require(_admin != address(0), "Invalid admin");
        
        primeToken = IERC20(_primeToken);
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(SLASHER_ROLE, _admin);
    }
    
    // ============ Staking Functions ============
    
    /**
     * @notice Stake PRIME tokens
     * @param amount Amount to stake
     * @param lockDuration Lock duration in seconds (0 for no lock)
     */
    function stake(uint256 amount, uint256 lockDuration) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        if (amount < MIN_STAKE) revert InsufficientAmount();
        if (lockDuration > MAX_LOCK_DURATION) revert InvalidLockDuration();
        if (stakes[msg.sender].amount > 0) revert AlreadyStaked();
        
        // Transfer tokens
        primeToken.safeTransferFrom(msg.sender, address(this), amount);
        
        // Calculate voting power (base + time bonus)
        uint256 votingPower = _calculateVotingPower(amount, lockDuration);
        
        stakes[msg.sender] = StakeInfo({
            amount: amount,
            lockEndTime: block.timestamp + lockDuration,
            lockDuration: lockDuration,
            lastRewardClaim: block.timestamp,
            votingPower: votingPower,
            delegate: msg.sender // Self-delegate by default
        });
        
        // Update delegate info
        delegates[msg.sender].delegatedVotingPower += votingPower;
        
        totalStaked += amount;
        totalVotingPower += votingPower;
        
        emit Staked(msg.sender, amount, lockDuration, votingPower);
    }
    
    /**
     * @notice Add more tokens to existing stake
     * @param amount Amount to add
     */
    function addToStake(uint256 amount) external nonReentrant whenNotPaused {
        StakeInfo storage info = stakes[msg.sender];
        if (info.amount == 0) revert NoStakeFound();
        
        // Claim pending rewards first
        _claimRewards(msg.sender);
        
        // Transfer tokens
        primeToken.safeTransferFrom(msg.sender, address(this), amount);
        
        // Update stake and voting power
        uint256 oldVotingPower = info.votingPower;
        info.amount += amount;
        info.votingPower = _calculateVotingPower(info.amount, info.lockDuration);
        
        // Update delegate
        uint256 powerDiff = info.votingPower - oldVotingPower;
        delegates[info.delegate].delegatedVotingPower += powerDiff;
        
        totalStaked += amount;
        totalVotingPower += powerDiff;
        
        emit Staked(msg.sender, amount, info.lockDuration, info.votingPower);
    }
    
    /**
     * @notice Unstake tokens after lock period ends
     */
    function unstake() external nonReentrant {
        StakeInfo storage info = stakes[msg.sender];
        
        if (info.amount == 0) revert NoStakeFound();
        if (block.timestamp < info.lockEndTime) revert StillLocked();
        
        // Claim pending rewards
        _claimRewards(msg.sender);
        
        uint256 amount = info.amount;
        uint256 votingPower = info.votingPower;
        
        // Update delegate
        delegates[info.delegate].delegatedVotingPower -= votingPower;
        
        // Clear stake
        delete stakes[msg.sender];
        
        totalStaked -= amount;
        totalVotingPower -= votingPower;
        
        // Transfer tokens back
        primeToken.safeTransfer(msg.sender, amount);
        
        emit Unstaked(msg.sender, amount);
    }
    
    /**
     * @notice Claim pending staking rewards
     */
    function claimRewards() external nonReentrant {
        _claimRewards(msg.sender);
    }
    
    // ============ Delegation Functions ============
    
    /**
     * @notice Delegate voting power to another address
     * @param delegatee Address to delegate to
     */
    function delegate(address delegatee) external {
        if (delegatee == address(0)) revert ZeroAddress();
        
        StakeInfo storage info = stakes[msg.sender];
        if (info.amount == 0) revert NoStakeFound();
        
        address oldDelegate = info.delegate;
        if (oldDelegate == delegatee) return;
        
        // Remove from old delegate
        delegates[oldDelegate].delegatedVotingPower -= info.votingPower;
        
        // Add to new delegate
        delegates[delegatee].delegatedVotingPower += info.votingPower;
        delegates[delegatee].delegators.push(msg.sender);
        
        info.delegate = delegatee;
        
        emit DelegateChanged(msg.sender, oldDelegate, delegatee, info.votingPower);
    }
    
    // ============ Slashing Functions ============
    
    /**
     * @notice Slash a staker for malicious behavior
     * @param user Address to slash
     * @param amount Amount to slash
     * @param reason Reason for slashing
     */
    function slash(
        address user,
        uint256 amount,
        string calldata reason
    ) external onlyRole(SLASHER_ROLE) {
        StakeInfo storage info = stakes[user];
        
        if (info.amount == 0) revert NoStakeFound();
        if (amount > info.amount) revert CannotSlashMore();
        
        // Reduce stake
        info.amount -= amount;
        totalStaked -= amount;
        
        // Recalculate voting power
        uint256 oldVotingPower = info.votingPower;
        info.votingPower = _calculateVotingPower(info.amount, info.lockDuration);
        
        // Update delegate
        uint256 powerLoss = oldVotingPower - info.votingPower;
        delegates[info.delegate].delegatedVotingPower -= powerLoss;
        totalVotingPower -= powerLoss;
        
        // Transfer slashed tokens to reward pool
        rewardPool += amount;
        
        emit Slashed(user, amount, reason);
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Fund the reward pool
     * @param amount Amount to add to reward pool
     */
    function fundRewardPool(uint256 amount) external {
        primeToken.safeTransferFrom(msg.sender, address(this), amount);
        rewardPool += amount;
        emit RewardPoolFunded(msg.sender, amount);
    }
    
    /**
     * @notice Pause staking
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause staking
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    // ============ Internal Functions ============
    
    /**
     * @notice Calculate voting power based on stake and lock duration
     */
    function _calculateVotingPower(
        uint256 amount,
        uint256 lockDuration
    ) internal pure returns (uint256) {
        // Base voting power = stake amount
        uint256 power = amount;
        
        // Time multiplier: up to 2x for max lock
        uint256 timeMultiplier = PRECISION + 
            (PRECISION * lockDuration) / MAX_LOCK_DURATION;
        
        return (power * timeMultiplier) / PRECISION;
    }
    
    /**
     * @notice Get APY based on lock duration
     */
    function _getAPY(uint256 lockDuration) internal pure returns (uint256) {
        if (lockDuration >= 365 days) return APY_365_DAYS;
        if (lockDuration >= 180 days) return APY_180_DAYS;
        if (lockDuration >= 90 days) return APY_90_DAYS;
        if (lockDuration >= 30 days) return APY_30_DAYS;
        return APY_NO_LOCK;
    }
    
    /**
     * @notice Claim rewards for a user
     */
    function _claimRewards(address user) internal {
        StakeInfo storage info = stakes[user];
        if (info.amount == 0) return;
        
        uint256 timePassed = block.timestamp - info.lastRewardClaim;
        if (timePassed == 0) return;
        
        uint256 apy = _getAPY(info.lockDuration);
        
        // Calculate rewards: (stake * APY * time) / (365 days * 10000)
        uint256 reward = (info.amount * apy * timePassed) / (365 days * 10000);
        
        // Cap at available reward pool
        if (reward > rewardPool) {
            reward = rewardPool;
        }
        
        if (reward > 0) {
            rewardPool -= reward;
            info.lastRewardClaim = block.timestamp;
            primeToken.safeTransfer(user, reward);
            
            emit RewardsClaimed(user, reward);
        }
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get stake info for a user
     */
    function getStakeInfo(address user) external view returns (StakeInfo memory) {
        return stakes[user];
    }
    
    /**
     * @notice Get voting power for an address (including delegated)
     */
    function getVotingPower(address user) external view returns (uint256) {
        return delegates[user].delegatedVotingPower;
    }
    
    /**
     * @notice Calculate pending rewards for a user
     */
    function pendingRewards(address user) external view returns (uint256) {
        StakeInfo memory info = stakes[user];
        if (info.amount == 0) return 0;
        
        uint256 timePassed = block.timestamp - info.lastRewardClaim;
        uint256 apy = _getAPY(info.lockDuration);
        
        uint256 reward = (info.amount * apy * timePassed) / (365 days * 10000);
        return reward > rewardPool ? rewardPool : reward;
    }
    
    /**
     * @notice Get APY for a lock duration
     */
    function getAPY(uint256 lockDuration) external pure returns (uint256) {
        return _getAPY(lockDuration);
    }
    
    /**
     * @notice Check if user can unstake
     */
    function canUnstake(address user) external view returns (bool) {
        StakeInfo memory info = stakes[user];
        return info.amount > 0 && block.timestamp >= info.lockEndTime;
    }
}
