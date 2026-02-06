// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Treasury
 * @author Prime AI
 * @notice DAO treasury for managing ecosystem funds
 * @dev Supports proposals, voting-based spending, and vesting schedules
 */
contract Treasury is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // ============ Constants ============
    
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    
    uint256 public constant PROPOSAL_DURATION = 7 days;
    uint256 public constant EXECUTION_DELAY = 2 days;
    uint256 public constant QUORUM_PERCENTAGE = 10; // 10% of total supply
    
    // ============ Enums ============
    
    enum ProposalStatus {
        PENDING,
        ACTIVE,
        SUCCEEDED,
        DEFEATED,
        EXECUTED,
        CANCELLED
    }
    
    // ============ Structs ============
    
    struct Proposal {
        uint256 id;
        address proposer;
        address recipient;
        uint256 amount;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        ProposalStatus status;
        bool executed;
    }
    
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 released;
        uint256 startTime;
        uint256 duration;
        uint256 cliff;
        bool revocable;
        bool revoked;
    }
    
    // ============ State Variables ============
    
    IERC20 public immutable primeToken;
    address public stakingContract;
    
    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    
    mapping(address => VestingSchedule) public vestingSchedules;
    
    // ============ Events ============
    
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address recipient,
        uint256 amount,
        string description
    );
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 votes
    );
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);
    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 amount,
        uint256 duration
    );
    event TokensReleased(address indexed beneficiary, uint256 amount);
    
    // ============ Errors ============
    
    error InvalidProposal();
    error AlreadyVoted();
    error VotingEnded();
    error VotingNotEnded();
    error ProposalNotSucceeded();
    error ExecutionDelayNotMet();
    error InsufficientVotingPower();
    error VestingNotStarted();
    error NoTokensToRelease();
    error VestingRevoked();
    
    // ============ Constructor ============
    
    constructor(address _primeToken, address _admin) {
        require(_primeToken != address(0), "Invalid token");
        require(_admin != address(0), "Invalid admin");
        
        primeToken = IERC20(_primeToken);
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(EXECUTOR_ROLE, _admin);
    }
    
    // ============ Proposal Functions ============
    
    /**
     * @notice Create a spending proposal
     * @param recipient Address to receive funds
     * @param amount Amount of PRIME to transfer
     * @param description Description of the proposal
     */
    function createProposal(
        address recipient,
        uint256 amount,
        string calldata description
    ) external returns (uint256) {
        if (recipient == address(0) || amount == 0) revert InvalidProposal();
        if (primeToken.balanceOf(address(this)) < amount) revert InvalidProposal();
        
        proposalCount++;
        
        proposals[proposalCount] = Proposal({
            id: proposalCount,
            proposer: msg.sender,
            recipient: recipient,
            amount: amount,
            description: description,
            startTime: block.timestamp,
            endTime: block.timestamp + PROPOSAL_DURATION,
            forVotes: 0,
            againstVotes: 0,
            status: ProposalStatus.ACTIVE,
            executed: false
        });
        
        emit ProposalCreated(
            proposalCount,
            msg.sender,
            recipient,
            amount,
            description
        );
        
        return proposalCount;
    }
    
    /**
     * @notice Vote on a proposal
     * @param proposalId ID of the proposal
     * @param support True for yes, false for no
     */
    function vote(uint256 proposalId, bool support) external {
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.status != ProposalStatus.ACTIVE) revert InvalidProposal();
        if (block.timestamp > proposal.endTime) revert VotingEnded();
        if (hasVoted[proposalId][msg.sender]) revert AlreadyVoted();
        
        // Get voting power from staking contract
        uint256 votingPower = _getVotingPower(msg.sender);
        if (votingPower == 0) revert InsufficientVotingPower();
        
        hasVoted[proposalId][msg.sender] = true;
        
        if (support) {
            proposal.forVotes += votingPower;
        } else {
            proposal.againstVotes += votingPower;
        }
        
        emit VoteCast(proposalId, msg.sender, support, votingPower);
    }
    
    /**
     * @notice Execute a successful proposal
     * @param proposalId ID of the proposal
     */
    function executeProposal(uint256 proposalId) 
        external 
        nonReentrant 
        onlyRole(EXECUTOR_ROLE) 
    {
        Proposal storage proposal = proposals[proposalId];
        
        if (block.timestamp <= proposal.endTime) revert VotingNotEnded();
        if (proposal.executed) revert InvalidProposal();
        
        // Check if proposal passed
        if (proposal.forVotes <= proposal.againstVotes) {
            proposal.status = ProposalStatus.DEFEATED;
            revert ProposalNotSucceeded();
        }
        
        // Check execution delay
        if (block.timestamp < proposal.endTime + EXECUTION_DELAY) {
            revert ExecutionDelayNotMet();
        }
        
        proposal.status = ProposalStatus.SUCCEEDED;
        proposal.executed = true;
        
        // Transfer funds
        primeToken.safeTransfer(proposal.recipient, proposal.amount);
        
        emit ProposalExecuted(proposalId);
    }
    
    /**
     * @notice Cancel a proposal (proposer only)
     * @param proposalId ID of the proposal
     */
    function cancelProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        
        if (msg.sender != proposal.proposer && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert InvalidProposal();
        }
        if (proposal.executed) revert InvalidProposal();
        
        proposal.status = ProposalStatus.CANCELLED;
        
        emit ProposalCancelled(proposalId);
    }
    
    // ============ Vesting Functions ============
    
    /**
     * @notice Create a vesting schedule for a beneficiary
     * @param beneficiary Address to receive vested tokens
     * @param amount Total amount to vest
     * @param duration Vesting duration in seconds
     * @param cliff Cliff period in seconds
     * @param revocable Whether the vesting can be revoked
     */
    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 duration,
        uint256 cliff,
        bool revocable
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(amount > 0, "Invalid amount");
        require(duration > 0, "Invalid duration");
        require(cliff <= duration, "Cliff exceeds duration");
        
        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            released: 0,
            startTime: block.timestamp,
            duration: duration,
            cliff: cliff,
            revocable: revocable,
            revoked: false
        });
        
        emit VestingScheduleCreated(beneficiary, amount, duration);
    }
    
    /**
     * @notice Release vested tokens
     */
    function releaseVestedTokens() external nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        
        if (schedule.revoked) revert VestingRevoked();
        if (block.timestamp < schedule.startTime + schedule.cliff) {
            revert VestingNotStarted();
        }
        
        uint256 releasable = _computeReleasable(schedule);
        if (releasable == 0) revert NoTokensToRelease();
        
        schedule.released += releasable;
        primeToken.safeTransfer(msg.sender, releasable);
        
        emit TokensReleased(msg.sender, releasable);
    }
    
    /**
     * @notice Revoke a vesting schedule
     * @param beneficiary Address to revoke vesting for
     */
    function revokeVesting(address beneficiary) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.revocable, "Not revocable");
        require(!schedule.revoked, "Already revoked");
        
        // Release any vested tokens first
        uint256 releasable = _computeReleasable(schedule);
        if (releasable > 0) {
            schedule.released += releasable;
            primeToken.safeTransfer(beneficiary, releasable);
        }
        
        schedule.revoked = true;
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Set the staking contract address
     * @param _stakingContract Address of the staking contract
     */
    function setStakingContract(address _stakingContract) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        stakingContract = _stakingContract;
    }
    
    /**
     * @notice Emergency withdraw tokens
     * @param token Token to withdraw
     * @param to Recipient
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(token).safeTransfer(to, amount);
    }
    
    // ============ Internal Functions ============
    
    function _getVotingPower(address user) internal view returns (uint256) {
        if (stakingContract == address(0)) {
            return primeToken.balanceOf(user);
        }
        // Call staking contract for voting power
        (bool success, bytes memory data) = stakingContract.staticcall(
            abi.encodeWithSignature("getVotingPower(address)", user)
        );
        if (success && data.length >= 32) {
            return abi.decode(data, (uint256));
        }
        return 0;
    }
    
    function _computeReleasable(VestingSchedule memory schedule) 
        internal 
        view 
        returns (uint256) 
    {
        if (block.timestamp < schedule.startTime + schedule.cliff) {
            return 0;
        }
        
        uint256 elapsed = block.timestamp - schedule.startTime;
        uint256 vested;
        
        if (elapsed >= schedule.duration) {
            vested = schedule.totalAmount;
        } else {
            vested = (schedule.totalAmount * elapsed) / schedule.duration;
        }
        
        return vested - schedule.released;
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get proposal details
     */
    function getProposal(uint256 proposalId) 
        external 
        view 
        returns (Proposal memory) 
    {
        return proposals[proposalId];
    }
    
    /**
     * @notice Get vesting schedule
     */
    function getVestingSchedule(address beneficiary) 
        external 
        view 
        returns (VestingSchedule memory) 
    {
        return vestingSchedules[beneficiary];
    }
    
    /**
     * @notice Get releasable amount for a beneficiary
     */
    function releasableAmount(address beneficiary) external view returns (uint256) {
        return _computeReleasable(vestingSchedules[beneficiary]);
    }
    
    /**
     * @notice Get treasury balance
     */
    function treasuryBalance() external view returns (uint256) {
        return primeToken.balanceOf(address(this));
    }
}
