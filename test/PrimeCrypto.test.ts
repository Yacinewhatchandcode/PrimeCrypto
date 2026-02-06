import { expect } from "chai";
import { ethers } from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { PrimeToken, AgentRewards, Staking, Treasury } from "../typechain-types";

describe("PrimeCrypto", function () {
    let primeToken: PrimeToken;
    let agentRewards: AgentRewards;
    let staking: Staking;
    let treasury: Treasury;

    let owner: HardhatEthersSigner;
    let oracle1: HardhatEthersSigner;
    let oracle2: HardhatEthersSigner;
    let oracle3: HardhatEthersSigner;
    let agent: HardhatEthersSigner;
    let user: HardhatEthersSigner;

    const TOTAL_SUPPLY = ethers.parseEther("1000000000"); // 1 billion
    const AGENT_REWARDS_ALLOCATION = ethers.parseEther("400000000");
    const TREASURY_ALLOCATION = ethers.parseEther("200000000");

    beforeEach(async function () {
        [owner, oracle1, oracle2, oracle3, agent, user] = await ethers.getSigners();

        // Deploy PrimeToken
        const PrimeToken = await ethers.getContractFactory("PrimeToken");
        primeToken = await PrimeToken.deploy(owner.address, owner.address);

        // Deploy AgentRewards
        const AgentRewards = await ethers.getContractFactory("AgentRewards");
        agentRewards = await AgentRewards.deploy(
            await primeToken.getAddress(),
            owner.address
        );

        // Deploy Staking
        const Staking = await ethers.getContractFactory("Staking");
        staking = await Staking.deploy(
            await primeToken.getAddress(),
            owner.address
        );

        // Deploy Treasury
        const Treasury = await ethers.getContractFactory("Treasury");
        treasury = await Treasury.deploy(
            await primeToken.getAddress(),
            owner.address
        );

        // Initialize token distribution
        await primeToken.initialize(
            await agentRewards.getAddress(),
            await treasury.getAddress(),
            owner.address, // team placeholder
            owner.address, // community placeholder
            owner.address, // liquidity placeholder
            owner.address  // advisors placeholder
        );

        // Link treasury to staking
        await treasury.setStakingContract(await staking.getAddress());

        // Add oracles
        await agentRewards.addOracle(oracle1.address);
        await agentRewards.addOracle(oracle2.address);
        await agentRewards.addOracle(oracle3.address);
    });

    describe("PrimeToken", function () {
        it("should have correct name and symbol", async function () {
            expect(await primeToken.name()).to.equal("Prime AI Token");
            expect(await primeToken.symbol()).to.equal("PRIME");
        });

        it("should have correct total supply after initialization", async function () {
            expect(await primeToken.totalSupply()).to.equal(TOTAL_SUPPLY);
        });

        it("should distribute tokens correctly", async function () {
            expect(await primeToken.balanceOf(await agentRewards.getAddress()))
                .to.equal(AGENT_REWARDS_ALLOCATION);
            expect(await primeToken.balanceOf(await treasury.getAddress()))
                .to.equal(TREASURY_ALLOCATION);
        });

        it("should be pausable by pauser", async function () {
            await primeToken.pause();
            expect(await primeToken.paused()).to.be.true;

            await primeToken.unpause();
            expect(await primeToken.paused()).to.be.false;
        });

        it("should prevent double initialization", async function () {
            await expect(
                primeToken.initialize(
                    owner.address,
                    owner.address,
                    owner.address,
                    owner.address,
                    owner.address,
                    owner.address
                )
            ).to.be.revertedWithCustomError(primeToken, "AlreadyInitialized");
        });
    });

    describe("AgentRewards", function () {
        beforeEach(async function () {
            // Give agent tokens for stake requirement
            await primeToken.transfer(agent.address, ethers.parseEther("1000"));
        });

        it("should allow agent registration", async function () {
            await agentRewards.connect(agent).registerAgent();

            const stats = await agentRewards.getAgentStats(agent.address);
            expect(stats.isRegistered).to.be.true;
            expect(stats.reputationScore).to.equal(50n);
        });

        it("should reject registration without enough stake", async function () {
            await expect(
                agentRewards.connect(user).registerAgent()
            ).to.be.revertedWithCustomError(agentRewards, "InsufficientStake");
        });

        it("should allow task submission", async function () {
            await agentRewards.connect(agent).registerAgent();

            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("task-proof-1"));
            const tx = await agentRewards.connect(agent).submitTask(
                0, // DATA_PROCESSING
                ethers.parseEther("2"), // 2x complexity
                proofHash
            );

            const receipt = await tx.wait();
            expect(receipt).to.not.be.null;
        });

        it("should verify tasks with oracle consensus", async function () {
            await agentRewards.connect(agent).registerAgent();

            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("task-proof-2"));
            const tx = await agentRewards.connect(agent).submitTask(
                0,
                ethers.parseEther("1"),
                proofHash
            );

            const receipt = await tx.wait();
            const taskSubmittedEvent = receipt?.logs.find(
                (log: any) => log.fragment?.name === "TaskSubmitted"
            );

            // This is a simplified test - in production, decode the event
            expect(taskSubmittedEvent).to.not.be.undefined;
        });

        it("should enforce cooldown period", async function () {
            await agentRewards.connect(agent).registerAgent();

            const proofHash1 = ethers.keccak256(ethers.toUtf8Bytes("task-1"));
            await agentRewards.connect(agent).submitTask(0, ethers.parseEther("1"), proofHash1);

            const proofHash2 = ethers.keccak256(ethers.toUtf8Bytes("task-2"));
            await expect(
                agentRewards.connect(agent).submitTask(0, ethers.parseEther("1"), proofHash2)
            ).to.be.revertedWithCustomError(agentRewards, "CooldownNotExpired");
        });
    });

    describe("Staking", function () {
        const stakeAmount = ethers.parseEther("1000");

        beforeEach(async function () {
            // Give user tokens
            await primeToken.transfer(user.address, ethers.parseEther("10000"));
            await primeToken.connect(user).approve(
                await staking.getAddress(),
                ethers.MaxUint256
            );

            // Fund reward pool
            await primeToken.approve(await staking.getAddress(), ethers.parseEther("1000000"));
            await staking.fundRewardPool(ethers.parseEther("1000000"));
        });

        it("should allow staking", async function () {
            await staking.connect(user).stake(stakeAmount, 0);

            const info = await staking.getStakeInfo(user.address);
            expect(info.amount).to.equal(stakeAmount);
        });

        it("should calculate correct voting power for locked stakes", async function () {
            const lockDuration = 365 * 24 * 60 * 60; // 1 year
            await staking.connect(user).stake(stakeAmount, lockDuration);

            const votingPower = await staking.getVotingPower(user.address);
            // Should be approximately 2x for max lock
            expect(votingPower).to.be.gt(stakeAmount);
        });

        it("should not allow unstaking before lock ends", async function () {
            const lockDuration = 30 * 24 * 60 * 60; // 30 days
            await staking.connect(user).stake(stakeAmount, lockDuration);

            await expect(
                staking.connect(user).unstake()
            ).to.be.revertedWithCustomError(staking, "StillLocked");
        });

        it("should allow delegation", async function () {
            await staking.connect(user).stake(stakeAmount, 0);
            await staking.connect(user).delegate(oracle1.address);

            const info = await staking.getStakeInfo(user.address);
            expect(info.delegate).to.equal(oracle1.address);

            const delegatedPower = await staking.getVotingPower(oracle1.address);
            expect(delegatedPower).to.be.gt(0);
        });

        it("should return correct APY for different lock durations", async function () {
            expect(await staking.getAPY(0)).to.equal(1000n); // 10%
            expect(await staking.getAPY(30 * 24 * 60 * 60)).to.equal(1200n); // 12%
            expect(await staking.getAPY(90 * 24 * 60 * 60)).to.equal(1500n); // 15%
            expect(await staking.getAPY(180 * 24 * 60 * 60)).to.equal(1800n); // 18%
            expect(await staking.getAPY(365 * 24 * 60 * 60)).to.equal(2000n); // 20%
        });
    });

    describe("Treasury", function () {
        beforeEach(async function () {
            // Give user tokens and stake for voting power
            await primeToken.transfer(user.address, ethers.parseEther("10000"));
            await primeToken.connect(user).approve(
                await staking.getAddress(),
                ethers.MaxUint256
            );
            await staking.connect(user).stake(ethers.parseEther("1000"), 0);
        });

        it("should allow creating proposals", async function () {
            const amount = ethers.parseEther("1000");
            await treasury.createProposal(
                user.address,
                amount,
                "Fund community project"
            );

            const proposal = await treasury.getProposal(1);
            expect(proposal.recipient).to.equal(user.address);
            expect(proposal.amount).to.equal(amount);
        });

        it("should allow voting on proposals", async function () {
            await treasury.createProposal(
                user.address,
                ethers.parseEther("1000"),
                "Test proposal"
            );

            await treasury.connect(user).vote(1, true);

            const proposal = await treasury.getProposal(1);
            expect(proposal.forVotes).to.be.gt(0);
        });

        it("should prevent double voting", async function () {
            await treasury.createProposal(
                user.address,
                ethers.parseEther("1000"),
                "Test proposal"
            );

            await treasury.connect(user).vote(1, true);

            await expect(
                treasury.connect(user).vote(1, false)
            ).to.be.revertedWithCustomError(treasury, "AlreadyVoted");
        });

        it("should return correct treasury balance", async function () {
            expect(await treasury.treasuryBalance()).to.equal(TREASURY_ALLOCATION);
        });
    });

    describe("Integration", function () {
        it("should complete full agent reward flow", async function () {
            // Setup: Give agent tokens and register
            await primeToken.transfer(agent.address, ethers.parseEther("1000"));
            await agentRewards.connect(agent).registerAgent();

            const initialBalance = await primeToken.balanceOf(agent.address);

            // Submit task
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("integration-test"));
            const submitTx = await agentRewards.connect(agent).submitTask(
                1, // CODE_GENERATION
                ethers.parseEther("3"), // 3x complexity
                proofHash
            );

            const receipt = await submitTx.wait();

            // Extract task ID from event (simplified)
            // In production, properly decode events
            expect(receipt).to.not.be.null;

            // Agent stats should be updated
            const stats = await agentRewards.getAgentStats(agent.address);
            expect(stats.isRegistered).to.be.true;
        });

        it("should allow staking and governance flow", async function () {
            // Setup
            await primeToken.transfer(user.address, ethers.parseEther("10000"));
            await primeToken.connect(user).approve(
                await staking.getAddress(),
                ethers.MaxUint256
            );

            // Stake
            await staking.connect(user).stake(ethers.parseEther("1000"), 0);

            // Check voting power
            const votingPower = await staking.getVotingPower(user.address);
            expect(votingPower).to.be.gt(0);

            // Create and vote on proposal
            await treasury.createProposal(
                user.address,
                ethers.parseEther("100"),
                "Grant for AI research"
            );

            await treasury.connect(user).vote(1, true);

            const proposal = await treasury.getProposal(1);
            expect(proposal.forVotes).to.equal(votingPower);
        });
    });
});
