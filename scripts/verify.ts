import { ethers, run } from "hardhat";
import * as fs from "fs";

async function main() {
    console.log("╔════════════════════════════════════════════════════════════╗");
    console.log("║           CONTRACT VERIFICATION SCRIPT                     ║");
    console.log("╚════════════════════════════════════════════════════════════╝");
    console.log("");

    // Load deployment data
    if (!fs.existsSync("deployments.json")) {
        console.error("deployments.json not found. Run deploy script first.");
        process.exit(1);
    }

    const deploymentData = JSON.parse(fs.readFileSync("deployments.json", "utf8"));
    const { contracts, deployer } = deploymentData;

    console.log(`Network: ${deploymentData.network} (${deploymentData.chainId})`);
    console.log("");

    // Verify PrimeToken
    console.log("1. Verifying PrimeToken...");
    try {
        await run("verify:verify", {
            address: contracts.PrimeToken,
            constructorArguments: [deployer, deployer],
        });
        console.log("   ✓ PrimeToken verified");
    } catch (error: any) {
        if (error.message.includes("Already Verified")) {
            console.log("   ⓘ PrimeToken already verified");
        } else {
            console.log(`   ✗ Error: ${error.message}`);
        }
    }

    // Verify AgentRewards
    console.log("2. Verifying AgentRewards...");
    try {
        await run("verify:verify", {
            address: contracts.AgentRewards,
            constructorArguments: [contracts.PrimeToken, deployer],
        });
        console.log("   ✓ AgentRewards verified");
    } catch (error: any) {
        if (error.message.includes("Already Verified")) {
            console.log("   ⓘ AgentRewards already verified");
        } else {
            console.log(`   ✗ Error: ${error.message}`);
        }
    }

    // Verify Staking
    console.log("3. Verifying Staking...");
    try {
        await run("verify:verify", {
            address: contracts.Staking,
            constructorArguments: [contracts.PrimeToken, deployer],
        });
        console.log("   ✓ Staking verified");
    } catch (error: any) {
        if (error.message.includes("Already Verified")) {
            console.log("   ⓘ Staking already verified");
        } else {
            console.log(`   ✗ Error: ${error.message}`);
        }
    }

    // Verify Treasury
    console.log("4. Verifying Treasury...");
    try {
        await run("verify:verify", {
            address: contracts.Treasury,
            constructorArguments: [contracts.PrimeToken, deployer],
        });
        console.log("   ✓ Treasury verified");
    } catch (error: any) {
        if (error.message.includes("Already Verified")) {
            console.log("   ⓘ Treasury already verified");
        } else {
            console.log(`   ✗ Error: ${error.message}`);
        }
    }

    console.log("");
    console.log("╔════════════════════════════════════════════════════════════╗");
    console.log("║              VERIFICATION COMPLETE                         ║");
    console.log("╚════════════════════════════════════════════════════════════╝");
    console.log("");
    console.log("View contracts on BaseScan:");
    const baseUrl = deploymentData.chainId === 8453
        ? "https://basescan.org"
        : "https://sepolia.basescan.org";
    console.log(`  PrimeToken:    ${baseUrl}/address/${contracts.PrimeToken}`);
    console.log(`  AgentRewards:  ${baseUrl}/address/${contracts.AgentRewards}`);
    console.log(`  Staking:       ${baseUrl}/address/${contracts.Staking}`);
    console.log(`  Treasury:      ${baseUrl}/address/${contracts.Treasury}`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
