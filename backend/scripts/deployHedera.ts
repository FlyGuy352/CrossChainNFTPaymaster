import { network } from "hardhat";

async function main() {
    const { viem } = await network.connect();
    const [deployer] = await viem.getWalletClients();
    console.log(`Deploying contract with the account: ${deployer.account.address}`);

    const nft = await viem.deployContract("HederaHybridNFT");
    console.log(`NFT Contract Address: ${nft.address}`);

    await nft.write.createNFTCollection(["HederaNFT", "HNFT"]);
}

main().catch(console.error);
