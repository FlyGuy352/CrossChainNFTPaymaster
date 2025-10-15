import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function verifyContract(
    contractAddress,
    sourceFilePath,
    metadataFilePath,
    verifierBaseUrl = "https://server-verify.hashscan.io"
) {
    // Read files
    if (!fs.existsSync(sourceFilePath)) throw new Error(`Missing ${sourceFilePath}`);
    if (!fs.existsSync(metadataFilePath)) throw new Error(`Missing ${metadataFilePath}`);

    const sourceCode = fs.readFileSync(sourceFilePath, "utf-8");
    const metadata = fs.readFileSync(metadataFilePath, "utf-8");

    const response = await fetch(`${verifierBaseUrl}/verify`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "*/*" },
        body: JSON.stringify({ 
            address: contractAddress, chain: "296", files: {
                "metadata.json": metadata, [sourceFilePath]: sourceCode
            }
        })
    });
    const result = await response.text();

    console.log(`HTTP Response Status: ${response.status}`);
    console.log(`Verification result: ${result}`);
}

// --- CLI arguments ---
const [,, contractAddress, sourceFilePath, metadataFilePath] = process.argv;

if (!contractAddress || !sourceFilePath || !metadataFilePath) {
    console.error("Usage: node verifyHedera.js <contractAddress> <source.sol> <metadata.json>");
    process.exit(1);
}

(async () => {
    try {
        const srcPath = path.resolve(sourceFilePath);
        const metaPath = path.resolve(metadataFilePath);
        await verifyContract(contractAddress, srcPath, metaPath);
    } catch (error) {
        console.error(`Verification failed: ${error.message}`);
        process.exit(1);
    }
})();