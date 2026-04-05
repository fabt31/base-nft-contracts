const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying NFT contracts with:", deployer.address);

  // Deploy BaseERC721
  const BaseERC721 = await ethers.getContractFactory("BaseERC721");
  const erc721 = await BaseERC721.deploy(
    "Base Genesis NFT",
    "BGNFT",
    "ipfs://QmYourBaseURIHere/",
    deployer.address,  // royalty recipient
    500                // 5% royalty
  );
  await erc721.deployed();
  console.log("BaseERC721 deployed:", erc721.address);

  // Deploy BaseERC1155
  const BaseERC1155 = await ethers.getContractFactory("BaseERC1155");
  const erc1155 = await BaseERC1155.deploy(
    "Base Multi Token",
    "BMT",
    "ipfs://QmYourBaseURIHere/{id}.json"
  );
  await erc1155.deployed();
  console.log("BaseERC1155 deployed:", erc1155.address);

  // Deploy BaseNFTMarket
  const BaseNFTMarket = await ethers.getContractFactory("BaseNFTMarket");
  const market = await BaseNFTMarket.deploy();
  await market.deployed();
  console.log("BaseNFTMarket deployed:", market.address);

  console.log("\n--- Summary ---");
  console.log("ERC721:", erc721.address);
  console.log("ERC1155:", erc1155.address);
  console.log("Market:", market.address);
  console.log("Basescan:", `https://basescan.org/address/${erc721.address}`);
}

main().catch((err) => { console.error(err); process.exit(1); });
