/**
 * Batch Mint Script for BaseERC721
 * Mints multiple NFTs to recipients from a JSON list.
 * Usage: node scripts/batch_mint.js <contractAddress> <recipients.json>
 */

const { ethers } = require("ethers");
require("dotenv").config();
const fs = require("fs");

const provider = new ethers.JsonRpcProvider(process.env.BASE_RPC || "https://mainnet.base.org");
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

const ERC721_ABI = [
  "function ownerMint(address to, string memory tokenURI) external",
  "function totalSupply() view returns (uint256)",
  "function mintPrice() view returns (uint256)"
];

async function batchMint(contractAddress, recipientsFile) {
  const recipients = JSON.parse(fs.readFileSync(recipientsFile, "utf8"));
  // Expected format: [{ "address": "0x...", "uri": "ipfs://..." }, ...]

  const nft = new ethers.Contract(contractAddress, ERC721_ABI, wallet);
  console.log("Contract:", contractAddress);
  console.log("Minting to", recipients.length, "recipients...");
  console.log("");

  let success = 0;
  let failed = 0;

  for (let i = 0; i < recipients.length; i++) {
    const { address, uri } = recipients[i];
    try {
      const tx = await nft.ownerMint(address, uri || "");
      const receipt = await tx.wait();
      console.log(`[${i + 1}/${recipients.length}] Minted to ${address} | tx: ${receipt.hash}`);
      success++;
    } catch (err) {
      console.error(`[${i + 1}/${recipients.length}] FAILED for ${address}: ${err.message}`);
      failed++;
    }
  }

  console.log("");
  console.log("Done. Success:", success, "| Failed:", failed);
}

const args = process.argv.slice(2);
if (args.length < 2) {
  console.log("Usage: node scripts/batch_mint.js <contractAddress> <recipients.json>");
  process.exit(1);
}

batchMint(args[0], args[1]).catch(console.error);
