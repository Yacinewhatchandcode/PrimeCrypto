# PrimeCrypto Launch Guide: From Zero to DEX Listing

## Complete Roadmap

```
┌─────────────────────────────────────────────────────────────────┐
│  STEP 1        STEP 2         STEP 3         STEP 4            │
│  Deploy        Add            List on        Start             │
│  Contracts     Liquidity      DEX            Trading           │
│  (~$20)        (~$100-500)    (FREE)         (EARNING!)        │
└─────────────────────────────────────────────────────────────────┘
```

---

## Step 1: Deploy to Base Mainnet (~$20)

### 1.1 Get Base ETH for Gas

You need ~0.01 ETH ($20-30) on Base network.

**Options:**
- Bridge from Ethereum: [bridge.base.org](https://bridge.base.org)
- Buy directly: Coinbase → Send to Base
- CEX withdrawal: Binance/Kraken → Base network

### 1.2 Configure Deployment

```bash
cd /Users/yacinebenhamou/PrimeCrypto

# Edit .env file with your REAL private key
nano .env
```

Add to `.env`:
```
PRIVATE_KEY=your_real_private_key_with_base_eth
BASESCAN_API_KEY=your_basescan_api_key
```

### 1.3 Deploy

```bash
npm run deploy:mainnet
```

This deploys all 4 contracts and outputs addresses.

### 1.4 Verify on BaseScan

```bash
npm run verify
```

Now your contracts are public and verified! ✅

---

## Step 2: Add Initial Liquidity (~$100-500)

### 2.1 Choose DEX

**Recommended for Base:**
- [Aerodrome](https://aerodrome.finance) - Largest Base DEX
- [Uniswap](https://app.uniswap.org) - Most recognized

### 2.2 Create Trading Pair

Go to Aerodrome → Liquidity → Create Pool

**Pool Setup:**
| Token A | Token B | Amount |
|---------|---------|--------|
| PRIME | ETH | Your choice |

**Example Initial Liquidity:**
| You Provide | Sets Price At |
|-------------|---------------|
| 10,000,000 PRIME + 1 ETH | $0.0003/PRIME |
| 10,000,000 PRIME + 5 ETH | $0.0015/PRIME |
| 10,000,000 PRIME + 10 ETH | $0.003/PRIME |

### 2.3 Lock Liquidity (Builds Trust)

Use [Team Finance](https://team.finance) or [Uncx](https://uncx.network) to lock LP tokens for 6-12 months.

**Cost:** ~$50-100
**Benefit:** Shows investors you won't "rug pull"

---

## Step 3: List and Announce

### 3.1 Token Listing Sites (FREE)

Submit PRIME to:
- [CoinGecko](https://coingecko.com/en/coins/new) - Apply for listing
- [CoinMarketCap](https://coinmarketcap.com/currencies/new/) - Apply for listing
- [DEXScreener](https://dexscreener.com) - Auto-lists after liquidity added
- [DEXTools](https://dextools.io) - Auto-lists after liquidity added

### 3.2 Trading Starts!

Once liquidity is added, anyone can:
- **Buy** PRIME with ETH
- **Sell** PRIME for ETH
- **Stake** PRIME for rewards
- **Vote** on governance

---

## Step 4: Revenue Generation

### Your Holdings After Launch

| Allocation | Amount | Vesting |
|------------|--------|---------|
| Team (You) | 150,000,000 PRIME | 2yr cliff, 4yr vest |
| Treasury | 200,000,000 PRIME | DAO controlled |
| Liquidity | 100,000,000 PRIME | 2yr lock |

### Revenue Streams

1. **Token Appreciation**
   - If PRIME reaches $0.01 → Team allocation = $1.5M
   - If PRIME reaches $0.10 → Team allocation = $15M

2. **Transaction Fees**
   - 0.5% of marketplace transactions
   - Goes to Treasury (you control via governance)

3. **Staking Rewards**
   - Stake your unlocked tokens
   - Earn 10-20% APY

4. **Enterprise Sales**
   - License the Agent Rewards system to companies
   - Charge monthly fees for API access

---

## Quick Start Costs Summary

| Item | Cost | Required? |
|------|------|-----------|
| Base ETH for deployment | ~$20 | Yes |
| Initial liquidity | $100-500 | Yes (your choice how much) |
| Liquidity lock | ~$50 | Recommended |
| CoinGecko/CMC listing | FREE | Recommended |
| **Total Minimum** | **~$170** | |

---

## Timeline

| Day | Action |
|-----|--------|
| Day 1 | Deploy to mainnet, verify contracts |
| Day 1 | Add initial liquidity on Aerodrome |
| Day 1 | Lock LP tokens |
| Day 2 | Submit to CoinGecko/CMC |
| Day 2 | Announce on social media |
| Week 1 | Trading begins, price discovery |
| Month 1 | Build community, integrate agents |
| Month 3+ | Revenue from fees starts flowing |

---

## Commands Reference

```bash
# Deploy to mainnet
npm run deploy:mainnet

# Verify contracts
npm run verify

# Check deployment addresses
cat deployments.json
```

---

## Next Action

**To start, you need:**
1. A wallet with ~$20-50 of ETH on Base network
2. Export the private key
3. Run the deploy command

**Do you have a wallet ready, or should I help you set one up?**
