const { ethers } = require("hardhat");

async function main() {
  const NFT_ADDRESS = process.env.NFT_ADDRESS;
  if (!NFT_ADDRESS) throw new Error("NFT_ADDRESS env var required");

  const [deployer] = await ethers.getSigners();
  console.log("Minting NFT from:", deployer.address);

  const ABI = [
    "function mint(string memory tokenURI_) external payable",
    "function mintPrice() view returns (uint256)",
    "function totalSupply() view returns (uint256)",
    "function ownerOf(uint256 tokenId) view returns (address)",
  ];
  const nft = new ethers.Contract(NFT_ADDRESS, ABI, deployer);

  const mintPrice = await nft.mintPrice();
  console.log("Mint price:", ethers.utils.formatEther(mintPrice), "ETH");

  const tokenURI = process.env.TOKEN_URI || "ipfs://QmDefaultMetadata";
  const tx = await nft.mint(tokenURI, { value: mintPrice });
  const receipt = await tx.wait();
  console.log("Minted! Tx:", receipt.transactionHash);

  const supply = await nft.totalSupply();
  console.log("New total supply:", supply.toString());
}

main().catch((err) => { console.error(err); process.exit(1); });
