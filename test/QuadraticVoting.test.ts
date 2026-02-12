import { expect } from "chai";
import { ethers } from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { QuadraticVoting, PrimeToken } from "../typechain-types";

describe("QuadraticVoting", function () {
    let quadVoting: QuadraticVoting;
    let primeToken: PrimeToken;
    let owner: HardhatEthersSigner;
    let voter1: HardhatEthersSigner;
    let voter2: HardhatEthersSigner;
    let whale: HardhatEthersSigner;

    const VOTER_TOKENS = ethers.parseEther("100000");  // 100k each
    const WHALE_TOKENS = ethers.parseEther("1000000"); // 1M whale
    const THREE_DAYS = 3 * 24 * 60 * 60;

    beforeEach(async function () {
        [owner, voter1, voter2, whale] = await ethers.getSigners();

        // Deploy PrimeToken
        const PrimeToken = await ethers.getContractFactory("PrimeToken");
        primeToken = await PrimeToken.deploy(owner.address, owner.address);

        // Initialize token with owner as all allocation recipients
        await primeToken.initialize(
            owner.address,
            owner.address,
            owner.address,
            owner.address,
            owner.address,
            owner.address
        );

        // Deploy QuadraticVoting
        const QuadVoting = await ethers.getContractFactory("QuadraticVoting");
        quadVoting = await QuadVoting.deploy(await primeToken.getAddress());

        // Distribute tokens
        await primeToken.transfer(voter1.address, VOTER_TOKENS);
        await primeToken.transfer(voter2.address, VOTER_TOKENS);
        await primeToken.transfer(whale.address, WHALE_TOKENS);

        // Approve quadratic voting contract
        await primeToken.connect(voter1).approve(
            await quadVoting.getAddress(), ethers.MaxUint256
        );
        await primeToken.connect(voter2).approve(
            await quadVoting.getAddress(), ethers.MaxUint256
        );
        await primeToken.connect(whale).approve(
            await quadVoting.getAddress(), ethers.MaxUint256
        );
    });

    describe("Proposal Creation", function () {
        it("should create a proposal", async function () {
            const tx = await quadVoting.createProposal(
                "Upgrade Agent Fleet",
                "Upgrade all agents to v2.0 architecture",
                THREE_DAYS,
                0 // PARAMETER_CHANGE
            );

            const receipt = await tx.wait();
            expect(receipt).to.not.be.null;

            const proposal = await quadVoting.getProposal(1);
            expect(proposal.title).to.equal("Upgrade Agent Fleet");
            expect(proposal.proposer).to.equal(owner.address);
        });

        it("should reject proposals with invalid duration", async function () {
            await expect(
                quadVoting.createProposal(
                    "Too short",
                    "desc",
                    60, // 1 minute — too short
                    0
                )
            ).to.be.revertedWithCustomError(quadVoting, "InvalidDuration");
        });

        it("should reject proposals from holders with insufficient tokens", async function () {
            const [, , , , poorUser] = await ethers.getSigners();
            await expect(
                quadVoting.connect(poorUser).createProposal(
                    "No tokens", "desc", THREE_DAYS, 0
                )
            ).to.be.revertedWithCustomError(quadVoting, "InsufficientTokens");
        });
    });

    describe("Quadratic Voting Mechanics", function () {
        beforeEach(async function () {
            await quadVoting.createProposal(
                "Test Proposal",
                "Testing quadratic voting",
                THREE_DAYS,
                4 // COMMUNITY
            );
        });

        it("should cost N² tokens for N votes", async function () {
            const costFor1 = await quadVoting.calculateVoteCost(1);
            const costFor3 = await quadVoting.calculateVoteCost(3);
            const costFor10 = await quadVoting.calculateVoteCost(10);

            expect(costFor1).to.equal(ethers.parseEther("1"));   // 1² = 1
            expect(costFor3).to.equal(ethers.parseEther("9"));   // 3² = 9
            expect(costFor10).to.equal(ethers.parseEther("100")); // 10² = 100
        });

        it("should allow casting votes", async function () {
            // Voter 1 casts 5 votes FOR (costs 25 tokens)
            await quadVoting.connect(voter1).castVote(1, 5, 0);

            const record = await quadVoting.getVoteRecord(1, voter1.address);
            expect(record.votesFor).to.equal(5);
            expect(record.tokensCommitted).to.equal(ethers.parseEther("25")); // 5² = 25
            expect(record.hasVoted).to.be.true;
        });

        it("should allow incremental voting", async function () {
            // First: 3 votes FOR (cost: 9 tokens)
            await quadVoting.connect(voter1).castVote(1, 3, 0);

            // Second: 2 more votes FOR (cost: 5² - 3² = 25 - 9 = 16 tokens)
            await quadVoting.connect(voter1).castVote(1, 2, 0);

            const record = await quadVoting.getVoteRecord(1, voter1.address);
            expect(record.votesFor).to.equal(5);
            expect(record.tokensCommitted).to.equal(ethers.parseEther("25")); // Total: 25
        });

        it("should prevent whale dominance", async function () {
            // Whale with 1M tokens tries to get 100 votes = costs 10,000 tokens
            // Regular voter with 100k tokens gets 10 votes = costs 100 tokens
            // Whale gets 10x more votes but needs 100x more tokens

            await quadVoting.connect(whale).castVote(1, 100, 0);
            await quadVoting.connect(voter1).castVote(1, 10, 0);

            const whaleRecord = await quadVoting.getVoteRecord(1, whale.address);
            const voter1Record = await quadVoting.getVoteRecord(1, voter1.address);

            // Whale: 100 votes, cost 10,000 tokens
            expect(whaleRecord.votesFor).to.equal(100);
            expect(whaleRecord.tokensCommitted).to.equal(ethers.parseEther("10000"));

            // Voter1: 10 votes, cost 100 tokens
            expect(voter1Record.votesFor).to.equal(10);
            expect(voter1Record.tokensCommitted).to.equal(ethers.parseEther("100"));

            // Whale paid 100x more but only got 10x the voting power
            const proposal = await quadVoting.getProposal(1);
            expect(proposal.forVotes).to.equal(110); // 100 + 10
        });

        it("should support FOR and AGAINST votes from same voter", async function () {
            // This shouldn't typically happen, but the contract allows split voting
            await quadVoting.connect(voter1).castVote(1, 3, 2);

            const record = await quadVoting.getVoteRecord(1, voter1.address);
            expect(record.votesFor).to.equal(3);
            expect(record.votesAgainst).to.equal(2);
            // Cost: 3² + 2² = 9 + 4 = 13
            expect(record.tokensCommitted).to.equal(ethers.parseEther("13"));
        });

        it("should reject zero votes", async function () {
            await expect(
                quadVoting.connect(voter1).castVote(1, 0, 0)
            ).to.be.revertedWithCustomError(quadVoting, "ZeroVotes");
        });
    });

    describe("Proposal Lifecycle", function () {
        beforeEach(async function () {
            await quadVoting.createProposal(
                "Lifecycle Test",
                "Testing full lifecycle",
                THREE_DAYS,
                1 // TREASURY_SPEND
            );
        });

        it("should not allow execution before voting ends", async function () {
            await quadVoting.connect(voter1).castVote(1, 10, 0);

            await expect(
                quadVoting.executeProposal(1)
            ).to.be.revertedWithCustomError(quadVoting, "VotingNotEnded");
        });

        it("should check quorum on execution", async function () {
            // Cast a small vote (1 vote = 1 token, nowhere near 100k quorum)
            await quadVoting.connect(voter1).castVote(1, 1, 0);

            // Fast forward past voting period
            await ethers.provider.send("evm_increaseTime", [THREE_DAYS + 1]);
            await ethers.provider.send("evm_mine", []);

            await expect(
                quadVoting.executeProposal(1)
            ).to.be.revertedWithCustomError(quadVoting, "QuorumNotReached");
        });

        it("should detect passed proposals", async function () {
            // Cast enough votes to meet quorum (need 100k tokens committed)
            // sqrt(100000) ≈ 316 votes → 316² = ~99,856 tokens. Use 317.
            await quadVoting.connect(whale).castVote(1, 317, 0);

            expect(await quadVoting.hasPassed(1)).to.be.false; // Still voting

            // Fast forward
            await ethers.provider.send("evm_increaseTime", [THREE_DAYS + 1]);
            await ethers.provider.send("evm_mine", []);

            expect(await quadVoting.hasPassed(1)).to.be.true;
        });

        it("should allow token withdrawal after voting ends", async function () {
            await quadVoting.connect(voter1).castVote(1, 10, 0);
            const balBefore = await primeToken.balanceOf(voter1.address);

            // Fast forward
            await ethers.provider.send("evm_increaseTime", [THREE_DAYS + 1]);
            await ethers.provider.send("evm_mine", []);

            await quadVoting.connect(voter1).withdrawTokens(1);

            const balAfter = await primeToken.balanceOf(voter1.address);
            expect(balAfter - balBefore).to.equal(ethers.parseEther("100")); // 10² = 100 refunded
        });
    });

    describe("Delegation", function () {
        it("should set delegate", async function () {
            await quadVoting.connect(voter1).delegate(voter2.address);
            expect(await quadVoting.delegates(voter1.address)).to.equal(voter2.address);
        });

        it("should return self as effective voter when no delegate", async function () {
            expect(await quadVoting.getEffectiveVoter(voter1.address)).to.equal(voter1.address);
        });

        it("should return delegate as effective voter", async function () {
            await quadVoting.connect(voter1).delegate(voter2.address);
            expect(await quadVoting.getEffectiveVoter(voter1.address)).to.equal(voter2.address);
        });
    });

    describe("Admin Controls", function () {
        it("should allow admin to cancel proposal", async function () {
            await quadVoting.createProposal("Cancel me", "desc", THREE_DAYS, 0);
            await quadVoting.cancelProposal(1);

            const proposal = await quadVoting.getProposal(1);
            expect(proposal.cancelled).to.be.true;
        });

        it("should allow admin to pause/unpause", async function () {
            await quadVoting.setPaused(true);

            await expect(
                quadVoting.createProposal("Paused", "desc", THREE_DAYS, 0)
            ).to.be.revertedWithCustomError(quadVoting, "ContractPaused");

            await quadVoting.setPaused(false);

            // Should work again
            const tx = await quadVoting.createProposal("Unpaused", "desc", THREE_DAYS, 0);
            expect(await tx.wait()).to.not.be.null;
        });

        it("should allow updating governance parameters", async function () {
            await quadVoting.setMinTokensToPropose(ethers.parseEther("500"));
            expect(await quadVoting.minTokensToPropose()).to.equal(ethers.parseEther("500"));

            await quadVoting.setQuorumTokens(ethers.parseEther("50000"));
            expect(await quadVoting.quorumTokens()).to.equal(ethers.parseEther("50000"));
        });
    });
});
