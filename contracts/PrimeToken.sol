// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title PrimeToken
 * @author Prime AI
 * @notice The official token of the Prime AI ecosystem - powering AI agent rewards and governance
 * @dev ERC-20 token with governance, burning, pausing, and permit functionality
 * 
 * Tokenomics:
 * - Total Supply: 1,000,000,000 PRIME (1 billion)
 * - Agent Rewards Pool: 40% (400M)
 * - Treasury/DAO: 20% (200M)
 * - Team & Development: 15% (150M)
 * - Community/Airdrops: 10% (100M)
 * - Liquidity: 10% (100M)
 * - Advisors/Legal: 5% (50M)
 */
contract PrimeToken is 
    ERC20, 
    ERC20Burnable, 
    ERC20Pausable, 
    ERC20Permit, 
    ERC20Votes, 
    AccessControl,
    ReentrancyGuard 
{
    // ============ Constants ============
    
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens
    uint256 public constant AGENT_REWARDS_ALLOCATION = 400_000_000 * 10**18; // 40%
    uint256 public constant TREASURY_ALLOCATION = 200_000_000 * 10**18; // 20%
    uint256 public constant TEAM_ALLOCATION = 150_000_000 * 10**18; // 15%
    uint256 public constant COMMUNITY_ALLOCATION = 100_000_000 * 10**18; // 10%
    uint256 public constant LIQUIDITY_ALLOCATION = 100_000_000 * 10**18; // 10%
    uint256 public constant ADVISORS_ALLOCATION = 50_000_000 * 10**18; // 5%
    
    // ============ State Variables ============
    
    address public agentRewardsContract;
    address public treasuryAddress;
    address public teamVestingContract;
    address public liquidityPool;
    address public advisorsVestingContract;
    
    bool public initialized;
    
    // ============ Events ============
    
    event AgentRewardsContractSet(address indexed contractAddress);
    event TreasuryAddressSet(address indexed treasuryAddress);
    event TokensDistributed(
        address indexed agentRewards,
        address indexed treasury,
        address indexed team
    );
    
    // ============ Errors ============
    
    error AlreadyInitialized();
    error ZeroAddress();
    error InvalidAllocation();
    
    // ============ Constructor ============
    
    /**
     * @notice Deploys the PrimeToken contract
     * @param defaultAdmin The address that will have the DEFAULT_ADMIN_ROLE
     * @param pauser The address that will have the PAUSER_ROLE
     */
    constructor(
        address defaultAdmin,
        address pauser
    ) 
        ERC20("Prime AI Token", "PRIME") 
        ERC20Permit("Prime AI Token") 
    {
        if (defaultAdmin == address(0) || pauser == address(0)) {
            revert ZeroAddress();
        }
        
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(MINTER_ROLE, defaultAdmin);
    }
    
    // ============ Initialization ============
    
    /**
     * @notice Initialize token distribution to ecosystem addresses
     * @dev Can only be called once. Sets up all allocation addresses and mints tokens
     * @param _agentRewards Address of the AgentRewards contract
     * @param _treasury Address of the DAO treasury
     * @param _teamVesting Address of the team vesting contract
     * @param _community Address for community allocation
     * @param _liquidity Address for liquidity provision
     * @param _advisorsVesting Address of advisors vesting contract
     */
    function initialize(
        address _agentRewards,
        address _treasury,
        address _teamVesting,
        address _community,
        address _liquidity,
        address _advisorsVesting
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (initialized) revert AlreadyInitialized();
        if (
            _agentRewards == address(0) ||
            _treasury == address(0) ||
            _teamVesting == address(0) ||
            _community == address(0) ||
            _liquidity == address(0) ||
            _advisorsVesting == address(0)
        ) {
            revert ZeroAddress();
        }
        
        initialized = true;
        
        agentRewardsContract = _agentRewards;
        treasuryAddress = _treasury;
        teamVestingContract = _teamVesting;
        liquidityPool = _liquidity;
        advisorsVestingContract = _advisorsVesting;
        
        // Mint and distribute tokens
        _mint(_agentRewards, AGENT_REWARDS_ALLOCATION);
        _mint(_treasury, TREASURY_ALLOCATION);
        _mint(_teamVesting, TEAM_ALLOCATION);
        _mint(_community, COMMUNITY_ALLOCATION);
        _mint(_liquidity, LIQUIDITY_ALLOCATION);
        _mint(_advisorsVesting, ADVISORS_ALLOCATION);
        
        // Grant minter role to agent rewards contract
        _grantRole(MINTER_ROLE, _agentRewards);
        
        emit TokensDistributed(_agentRewards, _treasury, _teamVesting);
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Pause all token transfers
     * @dev Only callable by accounts with PAUSER_ROLE
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause token transfers
     * @dev Only callable by accounts with PAUSER_ROLE
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    /**
     * @notice Update the agent rewards contract address
     * @param newAgentRewards New agent rewards contract address
     */
    function setAgentRewardsContract(address newAgentRewards) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        if (newAgentRewards == address(0)) revert ZeroAddress();
        
        // Revoke minter role from old contract
        if (agentRewardsContract != address(0)) {
            _revokeRole(MINTER_ROLE, agentRewardsContract);
        }
        
        agentRewardsContract = newAgentRewards;
        _grantRole(MINTER_ROLE, newAgentRewards);
        
        emit AgentRewardsContractSet(newAgentRewards);
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get the circulating supply (total supply minus locked allocations)
     * @return The circulating supply
     */
    function circulatingSupply() external view returns (uint256) {
        uint256 locked = balanceOf(agentRewardsContract) +
                        balanceOf(teamVestingContract) +
                        balanceOf(advisorsVestingContract);
        return totalSupply() - locked;
    }
    
    // ============ Required Overrides ============
    
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable, ERC20Votes)
    {
        super._update(from, to, value);
    }
    
    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
