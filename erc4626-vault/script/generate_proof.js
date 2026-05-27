const snarkjs = require("snarkjs");
const fs = require("fs");

async function generateProof() {
    // Example: Vault has these positions (private)
    const positions = [
        "1000000000000", // 1M USDC (6 decimals, so 1e12)
        "2000000000000", // 2M USDC in Aave
        "500000000000",  // 500k USDC buffer
        "0", "0", "0", "0", "0", "0", "0" // Unused positions
    ];
    
    const salt = "12345678"; // Random salt to prevent brute-forcing
    
    // Calculate total
    const totalAssets = positions.reduce(
        (sum, pos) => sum + BigInt(pos), 
        BigInt(0)
    );
    
    const timestamp = Math.floor(Date.now() / 1000);
    
    // Create input object
    const input = {
        positions: positions,
        salt: salt,
        totalAssets: totalAssets.toString(),
        timestamp: timestamp.toString()
    };
    
    console.log("Generating proof...");
    console.log("Total Assets:", totalAssets.toString());
    
    // Generate witness and proof
    const { proof, publicSignals } = await snarkjs.groth16.fullProve(
        input,
        "zk/build/reserves_js/reserves.wasm",
        "zk/build/reserves_final.zkey"
    );
    
    console.log("\nProof generated!");
    console.log("Commitment:", publicSignals[0]);
    
    // Format perfectly for our Solidity verifier interface
    const proofForSolidity = {
        a: [proof.pi_a[0], proof.pi_a[1]],
        b: [
            [proof.pi_b[0][1], proof.pi_b[0][0]],
            [proof.pi_b[1][1], proof.pi_b[1][0]]
        ],
        c: [proof.pi_c[0], proof.pi_c[1]],
        totalAssets: publicSignals[1],
        commitment: publicSignals[0],
        timestamp: publicSignals[2]
    };
    
    // Save to file
    fs.writeFileSync(
        "proof.json",
        JSON.stringify(proofForSolidity, null, 2)
    );
    
    console.log("\nProof saved to proof.json");
    console.log("Submit this to ProofOfReserves.submitProof()");
}

generateProof().catch(console.error);