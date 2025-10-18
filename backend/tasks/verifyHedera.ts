import { task } from "hardhat/config";
import fs from "fs";
import path from "path";

task("verifyHedera", "Verify Hedera contract")
    .addPositionalArgument({ name: "contractAddress", description: "Contract Address" })
    .addPositionalArgument({ name: "sourceFilePath", description: "Path to the source file" })
    .addPositionalArgument({ name: "metadataFilePath", description: "Path to the metadata JSON" })
    .setAction(async () => ({
        default: async args => {
            const { contractAddress, sourceFilePath, metadataFilePath } = args;

            const resolvedSourceFilePath = path.resolve(sourceFilePath);
            const resolvedMetadataFilePath = path.resolve(metadataFilePath);

            if (!fs.existsSync(resolvedSourceFilePath)) throw new Error(`Missing ${resolvedSourceFilePath}`);
            if (!fs.existsSync(resolvedMetadataFilePath)) throw new Error(`Missing ${resolvedMetadataFilePath}`);

            const sourceCode = fs.readFileSync(resolvedSourceFilePath, "utf-8");
            const metadata = fs.readFileSync(resolvedMetadataFilePath, "utf-8");

            const response = await fetch("https://server-verify.hashscan.io/verify", {
                method: "POST",
                headers: { "Content-Type": "application/json", Accept: "*/*" },
                body: JSON.stringify({
                    address: contractAddress,
                    chain: "296",
                    files: {
                        "metadata.json": metadata,
                        [resolvedSourceFilePath]: sourceCode
                    },
                })
            });

            const result = await response.text();
            console.log(`HTTP Response Status: ${response.status}`);
            console.log(`Verification result: ${result}`);
        }
    }));