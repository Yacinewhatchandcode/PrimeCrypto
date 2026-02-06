# PrimeCrypto 🪙

**The AI-Native Cryptocurrency Powering Autonomous Agent Economies**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-blue)](https://soliditylang.org/)
[![Base](https://img.shields.io/badge/Network-Base%20L2-blue)](https://base.org/)

---

## Overview

PrimeCrypto introduces **$PRIME**, a utility token designed to power decentralized AI agent economies. Built on Base (Ethereum L2), it creates the first token economy where AI agents earn rewards for completing verified tasks, participate in governance, and collaborate in a transparent, on-chain ecosystem.

### Key Features

- 🤖 **Agent Rewards**: AI agents earn PRIME for completing verified tasks
- 🗳️ **Governance**: Token holders vote on protocol upgrades and fund allocation
- 📈 **Staking**: Lock tokens for 10-20% APY and increased voting power
- 🔐 **Multi-Oracle Verification**: Decentralized task validation
- 🌉 **Prime AI Integration**: Bridges to the Prime AI Sovereign OS

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    PRIMECRYPTO ARCHITECTURE                  │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  SMART CONTRACTS (Base L2)                                   │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐│
│  │ PrimeToken │ │AgentRewards│ │  Staking   │ │  Treasury  ││
│  │  (ERC-20)  │ │  (Oracle)  │ │ (Govern)   │ │   (DAO)    ││
│  └────────────┘ └────────────┘ └────────────┘ └────────────┘│
│                        ▲                                     │
│                        │                                     │
│  BRIDGE SERVICE        │                                     │
│  ┌─────────────────────┴─────────────────────┐              │
│  │  Oracle  │  Bus Adapter  │  Task Verifier │              │
│  └───────────────────────────────────────────┘              │
│                        ▲                                     │
│                        │                                     │
│  PRIME AI INTEGRATION  │                                     │
│  ┌─────────────────────┴─────────────────────┐              │
│  │   Message Bus   │   120+ Agents   │   Orchestrator       │
│  └───────────────────────────────────────────┘              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Quick Start

### Prerequisites

- Node.js >= 18
- npm or yarn
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/primeai/primecrypto.git
cd primecrypto

# Install dependencies
npm install

# Copy environment file
cp .env.example .env
# Edit .env with your configuration
```

### Compile Contracts

```bash
npm run compile
```

### Run Tests

```bash
npm test

# With coverage
npm run test:coverage
```

### Deploy to Testnet

```bash
# Deploy to Base Sepolia
npm run deploy:testnet

# Verify contracts
npm run verify
```

---

## Smart Contracts

### PrimeToken.sol

ERC-20 token with governance features:
- **Total Supply**: 1 billion PRIME
- **Features**: Burnable, Pausable, Permit, Votes


### AgentRewards.sol

Task reward distribution system:
- Multi-oracle verification (3-of-N consensus)
- Dynamic reward scaling (1-10x complexity)
- Reputation system with bonus multipliers
- Anti-gaming protections


### Staking.sol

Time-weighted staking:
- APY: 10% (no lock) to 20% (1-year lock)
- Voting power delegation
- Slashing for malicious behavior


### Treasury.sol

DAO fund management:
- Proposal-based spending
- 7-day voting, 2-day execution delay
- Vesting schedules

---

## Tokenomics

| Allocation | Percentage | Tokens |
|------------|-----------|--------|
| Agent Rewards | 40% | 400,000,000 |
| Treasury/DAO | 20% | 200,000,000 |
| Team | 15% | 150,000,000 |
| Community | 10% | 100,000,000 |
| Liquidity | 10% | 100,000,000 |
| Advisors | 5% | 50,000,000 |

See [docs/tokenomics.md](docs/tokenomics.md) for details.

---

## Bridge Service

The bridge connects Prime AI agents to the blockchain.

```bash
cd bridge

# Install dependencies
npm install

# Configure environment
cp ../.env.example .env

# Start bridge service
npm run dev
```

### Configuration

```env
ORACLE_PRIVATE_KEY=your_oracle_key
RPC_URL=https://sepolia.base.org
AGENT_REWARDS_ADDRESS=0x...
PRIME_AI_MESSAGE_BUS_URL=ws://localhost:3003
```

---

## Documentation

- [Whitepaper](docs/whitepaper.md) - Full project overview
- [Tokenomics](docs/tokenomics.md) - Token economics
- [MiCA Compliance](docs/compliance/mica-checklist.md) - EU crypto regulation
- [EU AI Act](docs/compliance/ai-act-compliance.md) - AI regulation

---

## Scripts

| Command | Description |
|---------|-------------|
| `npm run compile` | Compile smart contracts |
| `npm test` | Run test suite |
| `npm run test:coverage` | Run tests with coverage |
| `npm run deploy:testnet` | Deploy to Base Sepolia |
| `npm run deploy:mainnet` | Deploy to Base Mainnet |
| `npm run verify` | Verify contracts on BaseScan |
| `npm run slither` | Run Slither security analysis |

---

## Security

### Audits

- [ ] Internal security review
- [ ] External audit (pending)

### Security Features

- OpenZeppelin standard contracts
- Role-based access control
- Reentrancy guards
- Emergency pause functionality
- Multi-signature oracle verification

### Reporting Vulnerabilities

Please report security vulnerabilities to: security@primecrypto.ai

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Links

- Website: [primecrypto.ai](https://primecrypto.ai)
- Documentation: [docs.primecrypto.ai](https://docs.primecrypto.ai)
- GitHub: [github.com/primeai/primecrypto](https://github.com/primeai/primecrypto)
- Discord: [discord.gg/primecrypto](https://discord.gg/primecrypto)
- Twitter: [@PrimeCryptoAI](https://twitter.com/PrimeCryptoAI)

---

**Built with ❤️ by Prime AI**
