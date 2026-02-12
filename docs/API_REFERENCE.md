# PrimeCrypto API Documentation

**Version**: 1.0.0
**Chain**: Base (Ethereum L2)
**Solidity**: ^0.8.24

---

## PrimeToken Contract API

### Read Functions

#### `name() → string`
Returns `"Prime AI Token"`.

#### `symbol() → string`
Returns `"PRIME"`.

#### `totalSupply() → uint256`
Returns `1,000,000,000 × 10^18` (1 billion tokens with 18 decimals).

#### `balanceOf(address account) → uint256`
Returns the token balance of `account`.

#### `circulatingSupply() → uint256`
Returns `totalSupply - (agentRewards balance + teamVesting balance + advisorsVesting balance)`.

#### `agentRewardsContract() → address`
Returns the current AgentRewards contract address.

#### `initialized() → bool`
Returns whether the token distribution has been executed.

#### `nonces(address owner) → uint256`
Returns the current EIP-2612 permit nonce for `owner`.

#### `getVotes(address account) → uint256`
Returns the current voting power of `account`.

#### `getPastVotes(address account, uint256 timepoint) → uint256`
Returns the voting power of `account` at `timepoint`.

---

### Write Functions

#### `initialize(address _agentRewards, address _treasury, address _teamVesting, address _community, address _liquidity, address _advisorsVesting)`
- **Access**: `DEFAULT_ADMIN_ROLE`
- **Effect**: Mints and distributes all allocations. Can only be called once.
- **Events**: `TokensDistributed(agentRewards, treasury, team)`

#### `transfer(address to, uint256 amount) → bool`
Standard ERC-20 transfer. Pauses respected.

#### `approve(address spender, uint256 amount) → bool`
Standard ERC-20 approval.

#### `permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)`
EIP-2612 gasless approval.

#### `delegate(address delegatee)`
Delegate voting power to `delegatee`.

#### `burn(uint256 amount)`
Burn tokens from caller's balance.

#### `pause()` / `unpause()`
- **Access**: `PAUSER_ROLE`
- Halts/resumes all token transfers.

#### `setAgentRewardsContract(address newAgentRewards)`
- **Access**: `DEFAULT_ADMIN_ROLE`
- Updates the agent rewards contract. Revokes old minter role, grants new.

---

## Staking Contract API

#### `stake(uint256 amount, uint256 lockDuration)`
Lock PRIME tokens for `lockDuration` seconds. Longer locks = higher rewards.

#### `unstake(uint256 stakeId)`
Withdraw staked tokens after lock period expires.

#### `claimRewards()`
Claim accumulated staking rewards.

#### `getStakeInfo(address user) → StakeInfo[]`
Returns all active stakes for a user.

#### `getRewardsAccrued(address user) → uint256`
Returns unclaimed rewards.

---

## Treasury Contract API

#### `createProposal(string description, address target, uint256 amount, bytes calldata data)`
- **Access**: Token holders with minimum voting power
- Create a new spending proposal.

#### `vote(uint256 proposalId, bool support)`
Vote on a proposal. Weight = voting power at proposal creation snapshot.

#### `executeProposal(uint256 proposalId)`
Execute a passed proposal after voting period ends.

#### `getProposal(uint256 proposalId) → Proposal`
Returns proposal details.

---

## AgentRewards Contract API

#### `registerAgent(bytes32 agentId, address agentWallet)`
- **Access**: `DEFAULT_ADMIN_ROLE`
- Register an AI agent for rewards.

#### `recordTask(bytes32 agentId, bytes32 taskHash, uint256 rewardAmount)`
- **Access**: `MINTER_ROLE`
- Record a completed task and distribute rewards.

#### `getAgentRewards(bytes32 agentId) → uint256`
Returns total rewards earned by an agent.

#### `getAgentTaskCount(bytes32 agentId) → uint256`
Returns number of tasks completed.

---

## BitcoinBridge Contract API

#### `initiateBridgeToBase(bytes32 btcTxHash, uint256 amount)`
Initiate a BTC → PRIME bridge transfer.

#### `completeBridge(bytes32 bridgeId)`
- **Access**: Bridge operator
- Complete the bridge transfer after BTC confirmation.

#### `cancelBridge(bytes32 bridgeId)`
Cancel a pending bridge transfer after timeout.

#### `getBridgeStatus(bytes32 bridgeId) → BridgeStatus`
Returns the current status of a bridge transfer.

---

## Events

| Event | Contract | Description |
|-------|----------|-------------|
| `TokensDistributed(agentRewards, treasury, team)` | PrimeToken | Initial distribution executed |
| `AgentRewardsContractSet(address)` | PrimeToken | Agent rewards address updated |
| `Staked(user, amount, duration, stakeId)` | Staking | Tokens staked |
| `Unstaked(user, amount, stakeId)` | Staking | Tokens unstaked |
| `RewardsClaimed(user, amount)` | Staking | Rewards claimed |
| `ProposalCreated(proposalId, proposer, description)` | Treasury | New proposal |
| `Voted(proposalId, voter, support, weight)` | Treasury | Vote cast |
| `ProposalExecuted(proposalId)` | Treasury | Proposal executed |
| `AgentRegistered(agentId, wallet)` | AgentRewards | New agent registered |
| `TaskRecorded(agentId, taskHash, reward)` | AgentRewards | Task completed |
| `BridgeInitiated(bridgeId, btcTxHash, amount)` | BitcoinBridge | Bridge started |
| `BridgeCompleted(bridgeId)` | BitcoinBridge | Bridge finished |

---

## Error Codes

| Error | Contract | Trigger |
|-------|----------|---------|
| `ZeroAddress()` | All | Address parameter is zero |
| `AlreadyInitialized()` | PrimeToken | `initialize()` called twice |
| `InvalidAllocation()` | PrimeToken | Allocation mismatch |
| `InsufficientBalance()` | Staking | Not enough tokens |
| `StillLocked()` | Staking | Unstake before lock period |
| `ProposalNotFound()` | Treasury | Invalid proposal ID |
| `VotingClosed()` | Treasury | Voting period ended |
| `BridgeExpired()` | BitcoinBridge | Bridge timeout |

---

## Integration Example (ethers.js)

```typescript
import { ethers } from "ethers";
import PrimeTokenABI from "./abi/PrimeToken.json";

const provider = new ethers.JsonRpcProvider("https://mainnet.base.org");
const primeToken = new ethers.Contract(
  "0x...", // Contract address (post-deploy)
  PrimeTokenABI,
  provider
);

// Read balance
const balance = await primeToken.balanceOf("0xYourAddress");
console.log("PRIME Balance:", ethers.formatEther(balance));

// Delegate voting power
const signer = provider.getSigner();
const tx = await primeToken.connect(signer).delegate("0xDelegateAddress");
await tx.wait();
```
