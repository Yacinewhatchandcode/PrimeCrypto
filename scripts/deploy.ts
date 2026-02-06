import { ethers } from "hardhat";

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("╔════════════════════════════════════════════════════════════╗");
    console.log("║           PRIMECRYPTO DEPLOYMENT SCRIPT                    ║");
    console.log("╚════════════════════════════════════════════════════════════╝");
    console.log("");
    console.log(`Deployer: ${deployer.address}`);
    console.log(`Balance: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH`);
    console.log("");

    // ============ Deploy PrimeToken ============
    console.log("1. Deploying PrimeToken...");
    const PrimeToken = await ethers.getContractFactory("PrimeToken");
    const primeToken = await PrimeToken.deploy(deployer.address, deployer.address);
    await primeToken.waitForDeployment();
    const primeTokenAddress = await primeToken.getAddress();
    console.log(`   ✓ PrimeToken deployed: ${primeTokenAddress}`);

    // ============ Deploy AgentRewards ============
    console.log("2. Deploying AgentRewards...");
    const AgentRewards = await ethers.getContractFactory("AgentRewards");
    const agentRewards = await AgentRewards.deploy(primeTokenAddress, deployer.address);
    await agentRewards.waitForDeployment();
    const agentRewardsAddress = await agentRewards.getAddress();
    console.log(`   ✓ AgentRewards deployed: ${agentRewardsAddress}`);

    // ============ Deploy Staking ============
    console.log("3. Deploying Staking...");
    const Staking = await ethers.getContractFactory("Staking");
    const staking = await Staking.deploy(primeTokenAddress, deployer.address);
    await staking.waitForDeployment();
    const stakingAddress = await staking.getAddress();
    console.log(`   ✓ Staking deployed: ${stakingAddress}`);

    // ============ Deploy Treasury ============
    console.log("4. Deploying Treasury...");
    const Treasury = await ethers.getContractFactory("Treasury");
    const treasury = await Treasury.deploy(primeTokenAddress, deployer.address);
    await treasury.waitForDeployment();
    const treasuryAddress = await treasury.getAddress();
    console.log(`   ✓ Treasury deployed: ${treasuryAddress}`);

    // ============ Initialize Token Distribution ============
    console.log("");
    console.log("5. Initializing token distribution...");

    // For initial deployment, we'll use deployer as placeholder for vesting contracts
    // In production, deploy proper vesting contracts first
    const tx = await primeToken.initialize(
        agentRewardsAddress,    // Agent Rewards: 400M
        treasuryAddress,        // Treasury: 200M
        deployer.address,       // Team (placeholder): 150M
        deployer.address,       // Community (deployer for airdrop): 100M
        deployer.address,       // Liquidity (deployer for LP setup): 100M
        deployer.address        // Advisors (placeholder): 50M
    );
    await tx.wait();
    console.log("   ✓ Token distribution initialized");

    // ============ Link Treasury to Staking ============
    console.log("6. Linking Treasury to Staking...");
    const linkTx = await treasury.setStakingContract(stakingAddress);
    await linkTx.wait();
    console.log("   ✓ Treasury linked to Staking");

    // ============ Fund Staking Reward Pool ============
    console.log("7. Funding staking reward pool...");
    const rewardPoolAmount = ethers.parseEther("10000000"); // 10M PRIME
    const approveTx = await primeToken.approve(stakingAddress, rewardPoolAmount);
    await approveTx.wait();
    const fundTx = await staking.fundRewardPool(rewardPoolAmount);
    await fundTx.wait();
    console.log(`   ✓ Funded staking with ${ethers.formatEther(rewardPoolAmount)} PRIME`);

    // ============ Summary ============
    console.log("");
    console.log("╔════════════════════════════════════════════════════════════╗");
    console.log("║                 DEPLOYMENT COMPLETE                        ║");
    console.log("╚════════════════════════════════════════════════════════════╝");
    console.log("");
    console.log("Contract Addresses:");
    console.log(`  PrimeToken:    ${primeTokenAddress}`);
    console.log(`  AgentRewards:  ${agentRewardsAddress}`);
    console.log(`  Staking:       ${stakingAddress}`);
    console.log(`  Treasury:      ${treasuryAddress}`);
    console.log("");
    console.log("Token Distribution:");
    console.log(`  Agent Rewards: ${ethers.formatEther(await primeToken.balanceOf(agentRewardsAddress))} PRIME`);
    console.log(`  Treasury:      ${ethers.formatEther(await primeToken.balanceOf(treasuryAddress))} PRIME`);
    console.log(`  Deployer:      ${ethers.formatEther(await primeToken.balanceOf(deployer.address))} PRIME`);
    console.log("");
    console.log("Next Steps:");
    console.log("  1. Verify contracts on BaseScan");
    console.log("  2. Add oracle addresses to AgentRewards");
    console.log("  3. Set up proper vesting contracts");
    console.log("  4. Add liquidity to DEX");
    console.log("");

    // Save deployment addresses
    const fs = require("fs");
    const deploymentData = {
        network: (await ethers.provider.getNetwork()).name,
        chainId: Number((await ethers.provider.getNetwork()).chainId),
        deployer: deployer.address,
        contracts: {
            PrimeToken: primeTokenAddress,
            AgentRewards: agentRewardsAddress,
            Staking: stakingAddress,
            Treasury: treasuryAddress,
        },
        timestamp: new Date().toISOString(),
    };

    fs.writeFileSync(
        "deployments.json",
        JSON.stringify(deploymentData, null, 2)
    );
    console.log("Deployment data saved to deployments.json");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
