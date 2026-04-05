/**
 * Generate Merkle root for whitelist minting.
 * Usage: node scripts/generate_merkle.js addresses.json
 */
const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");
const fs = require("fs");

function generateMerkleTree(addresses) {
  const leaves = addresses.map((addr) =>
    keccak256(Buffer.from(addr.replace("0x", ""), "hex"))
  );
  const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
  return tree;
}

function getProof(tree, address) {
  const leaf = keccak256(Buffer.from(address.replace("0x", ""), "hex"));
  return tree.getHexProof(leaf);
}

async function main() {
  const inputFile = process.argv[2];
  if (!inputFile) {
    console.error("Usage: node generate_merkle.js <addresses.json>");
    process.exit(1);
  }

  const addresses = JSON.parse(fs.readFileSync(inputFile, "utf8"));
  console.log(`Generating Merkle tree for ${addresses.length} addresses...`);

  const tree = generateMerkleTree(addresses);
  const root = tree.getHexRoot();

  console.log("Merkle Root:", root);

  const proofs = {};
  for (const addr of addresses) {
    proofs[addr] = getProof(tree, addr);
  }

  const output = { root, proofs };
  fs.writeFileSync("merkle_output.json", JSON.stringify(output, null, 2));
  console.log("Proofs saved to merkle_output.json");
  console.log("Set this root in your contract with setMerkleRoot()");
}

main().catch(console.error);
