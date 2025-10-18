import fs from "fs";
import path from "path";

const args = process.argv.slice(2);

const [
    contractAddress, sourceFilePath, metadataFilePath, verifierBaseUrl = "https://server-verify.hashscan.io"
] = args;

const resolvedSourceFilePath = path.resolve(sourceFilePath);
const resolvedMetadataFilePath = path.resolve(metadataFilePath);

if (!fs.existsSync(resolvedSourceFilePath)) throw new Error(`Missing ${resolvedSourceFilePath}`);
if (!fs.existsSync(resolvedMetadataFilePath)) throw new Error(`Missing ${resolvedMetadataFilePath}`);

const sourceCode = fs.readFileSync(resolvedSourceFilePath, "utf-8");
const metadata = fs.readFileSync(resolvedMetadataFilePath, "utf-8");

const response = await fetch(`${verifierBaseUrl}/verify`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "*/*" },
    body: JSON.stringify({ 
        address: contractAddress, chain: "296", files: {
            "metadata.json": metadata, [resolvedSourceFilePath]: sourceCode
        }
    })
});
const result = await response.text();

console.log(`HTTP Response Status: ${response.status}`);
console.log(`Verification result: ${result}`);