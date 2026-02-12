// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title QuadraticVoting
 * @notice Quadratic voting system for PrimeCrypto governance
 * @dev Voting power = sqrt(tokens_committed). Cost for N votes = N² tokens.
 * 
 * Key features:
 * - Quadratic cost: prevents whale dominance
 * - Time-bounded proposals with configurable duration
 * - Support for multiple concurrent proposals
 * - Vote delegation support
 * - Emergency pause capability
 */
contract QuadraticVoting is AccessControl, ReentrancyGuard {
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    IERC20 public immutable primeToken;

    // ── Proposal ─────────────────────────────────────────────────
    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        uint256 forVotes;      // Total quadratic votes FOR
        uint256 againstVotes;  // Total quadratic votes AGAINST
        uint256 totalTokensCommitted;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool cancelled;
        ProposalType proposalType;
    }

    enum ProposalType {
        PARAMETER_CHANGE,    // Change system parameters
        TREASURY_SPEND,      // Spend from treasury
        AGENT_UPGRADE,       // Upgrade agent capabilities
        PROTOCOL_UPGRADE,    // Protocol-level changes
        COMMUNITY            // Community proposals
    }

    // ── Vote Record ──────────────────────────────────────────────
    struct VoteRecord {
        uint256 votesFor;       // Number of quadratic votes FOR
        uint256 votesAgainst;   // Number of quadratic votes AGAINST
        uint256 tokensCommitted; // Total tokens locked
        bool hasVoted;
    }

    // ── Storage ──────────────────────────────────────────────────
    uint256 public proposalCount;
    uint256 public minProposalDuration = 3 days;
    uint256 public maxProposalDuration = 14 days;
    uint256 public minTokensToPropose = 1000 * 1e18; // 1000 PRIME
    uint256 public quorumTokens = 100_000 * 1e18;    // 100k PRIME quorum

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => VoteRecord)) public votes;
    mapping(address => address) public delegates; // voter => delegate

    bool public paused;

    // ── Events ───────────────────────────────────────────────────
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        ProposalType proposalType,
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 tokensCommitted
    );

    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);
    event DelegateChanged(address indexed delegator, address indexed newDelegate);
    event Paused(bool isPaused);

    // ── Errors ───────────────────────────────────────────────────
    error ProposalNotActive();
    error InsufficientTokens();
    error AlreadyExecuted();
    error QuorumNotReached();
    error VotingNotEnded();
    error VotingEnded();
    error InvalidDuration();
    error ContractPaused();
    error ZeroVotes();

    // ── Constructor ──────────────────────────────────────────────
    constructor(address _primeToken) {
        primeToken = IERC20(_primeToken);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PROPOSER_ROLE, msg.sender);
    }

    // ── Modifiers ────────────────────────────────────────────────
    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    // ── Core Functions ───────────────────────────────────────────

    /**
     * @notice Create a new proposal
     * @param title Short title
     * @param description Full description
     * @param duration Voting duration in seconds
     * @param proposalType Category of the proposal
     */
    function createProposal(
        string calldata title,
        string calldata description,
        uint256 duration,
        ProposalType proposalType
    ) external whenNotPaused returns (uint256) {
        if (duration < minProposalDuration || duration > maxProposalDuration)
            revert InvalidDuration();
        
        if (primeToken.balanceOf(msg.sender) < minTokensToPropose)
            revert InsufficientTokens();

        proposalCount++;
        uint256 proposalId = proposalCount;

        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            title: title,
            description: description,
            forVotes: 0,
            againstVotes: 0,
            totalTokensCommitted: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            executed: false,
            cancelled: false,
            proposalType: proposalType
        });

        emit ProposalCreated(
            proposalId,
            msg.sender,
            title,
            proposalType,
            block.timestamp,
            block.timestamp + duration
        );

        return proposalId;
    }

    /**
     * @notice Cast quadratic votes on a proposal
     * @dev Cost = (currentVotes + newVotes)² - currentVotes² tokens
     * @param proposalId The proposal to vote on
     * @param votesFor Number of quadratic votes FOR
     * @param votesAgainst Number of quadratic votes AGAINST
     */
    function castVote(
        uint256 proposalId,
        uint256 votesFor,
        uint256 votesAgainst
    ) external nonReentrant whenNotPaused {
        Proposal storage proposal = proposals[proposalId];
        
        if (block.timestamp < proposal.startTime || block.timestamp > proposal.endTime)
            revert ProposalNotActive();
        if (votesFor == 0 && votesAgainst == 0) revert ZeroVotes();

        VoteRecord storage record = votes[proposalId][msg.sender];

        // Calculate quadratic cost
        // Cost for N votes = N². Incremental cost = (existing + new)² - existing²
        uint256 existingForCost = record.votesFor * record.votesFor;
        uint256 existingAgainstCost = record.votesAgainst * record.votesAgainst;
        uint256 newForTotal = record.votesFor + votesFor;
        uint256 newAgainstTotal = record.votesAgainst + votesAgainst;
        uint256 newForCost = newForTotal * newForTotal;
        uint256 newAgainstCost = newAgainstTotal * newAgainstTotal;

        uint256 additionalCost = (newForCost - existingForCost + newAgainstCost - existingAgainstCost) * 1e18;

        // Transfer tokens (they're locked until proposal ends)
        if (primeToken.balanceOf(msg.sender) < additionalCost)
            revert InsufficientTokens();
        
        primeToken.transferFrom(msg.sender, address(this), additionalCost);

        // Update records
        record.votesFor = newForTotal;
        record.votesAgainst = newAgainstTotal;
        record.tokensCommitted += additionalCost;
        record.hasVoted = true;

        proposal.forVotes += votesFor;
        proposal.againstVotes += votesAgainst;
        proposal.totalTokensCommitted += additionalCost;

        emit VoteCast(proposalId, msg.sender, votesFor, votesAgainst, additionalCost);
    }

    /**
     * @notice Execute a passed proposal
     * @param proposalId The proposal to execute
     */
    function executeProposal(uint256 proposalId) external whenNotPaused {
        Proposal storage proposal = proposals[proposalId];
        
        if (block.timestamp <= proposal.endTime) revert VotingNotEnded();
        if (proposal.executed) revert AlreadyExecuted();
        if (proposal.totalTokensCommitted < quorumTokens) revert QuorumNotReached();

        proposal.executed = true;

        emit ProposalExecuted(proposalId);
    }

    /**
     * @notice Withdraw tokens after voting period ends
     * @param proposalId The proposal to withdraw from
     */
    function withdrawTokens(uint256 proposalId) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        if (block.timestamp <= proposal.endTime && !proposal.cancelled) 
            revert VotingNotEnded();

        VoteRecord storage record = votes[proposalId][msg.sender];
        uint256 amount = record.tokensCommitted;
        if (amount == 0) revert InsufficientTokens();

        record.tokensCommitted = 0;
        primeToken.transfer(msg.sender, amount);
    }

    /**
     * @notice Delegate your voting power to another address
     * @param delegatee The address to delegate to
     */
    function delegate(address delegatee) external {
        delegates[msg.sender] = delegatee;
        emit DelegateChanged(msg.sender, delegatee);
    }

    // ── View Functions ───────────────────────────────────────────

    /**
     * @notice Calculate the token cost for a given number of votes
     * @param numVotes Number of quadratic votes
     * @return cost in tokens (with 18 decimals)
     */
    function calculateVoteCost(uint256 numVotes) public pure returns (uint256) {
        return numVotes * numVotes * 1e18;
    }

    /**
     * @notice Get proposal details
     */
    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        return proposals[proposalId];
    }

    /**
     * @notice Get vote record for a voter on a proposal
     */
    function getVoteRecord(uint256 proposalId, address voter) 
        external view returns (VoteRecord memory) 
    {
        return votes[proposalId][voter];
    }

    /**
     * @notice Check if a proposal has passed
     */
    function hasPassed(uint256 proposalId) external view returns (bool) {
        Proposal memory p = proposals[proposalId];
        return p.forVotes > p.againstVotes && 
               p.totalTokensCommitted >= quorumTokens &&
               block.timestamp > p.endTime;
    }

    /**
     * @notice Get the effective voting power (considering delegation)
     */
    function getEffectiveVoter(address voter) public view returns (address) {
        address delegatee = delegates[voter];
        return delegatee == address(0) ? voter : delegatee;
    }

    // ── Admin Functions ──────────────────────────────────────────

    function cancelProposal(uint256 proposalId) external onlyRole(ADMIN_ROLE) {
        proposals[proposalId].cancelled = true;
        emit ProposalCancelled(proposalId);
    }

    function setMinProposalDuration(uint256 _duration) external onlyRole(ADMIN_ROLE) {
        minProposalDuration = _duration;
    }

    function setMaxProposalDuration(uint256 _duration) external onlyRole(ADMIN_ROLE) {
        maxProposalDuration = _duration;
    }

    function setMinTokensToPropose(uint256 _amount) external onlyRole(ADMIN_ROLE) {
        minTokensToPropose = _amount;
    }

    function setQuorumTokens(uint256 _amount) external onlyRole(ADMIN_ROLE) {
        quorumTokens = _amount;
    }

    function setPaused(bool _paused) external onlyRole(ADMIN_ROLE) {
        paused = _paused;
        emit Paused(_paused);
    }
}
