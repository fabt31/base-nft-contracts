const { expect } = require("chai");
const { ethers } = require("hardhat");
const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");

describe("BaseWhitelistNFT", function () {
  let nft, owner, wl1, wl2, notListed;
  let merkleTree, merkleRoot;

  beforeEach(async function () {
    [owner, wl1, wl2, notListed] = await ethers.getSigners();

    // Build whitelist
    const whitelist = [wl1.address, wl2.address];
    const leaves = whitelist.map((addr) =>
      keccak256(Buffer.from(addr.replace("0x", ""), "hex"))
    );
    merkleTree = new MerkleTree(leaves, keccak256, { sortPairs: true });
    merkleRoot = merkleTree.getHexRoot();

    const BaseWhitelistNFT = await ethers.getContractFactory("BaseWhitelistNFT");
    nft = await BaseWhitelistNFT.deploy("WL NFT", "WLNFT", "ipfs://wl/");
    await nft.deployed();

    await nft.connect(owner).setMerkleRoot(merkleRoot);
    await nft.connect(owner).setWhitelistActive(true);
  });

  function getProof(address) {
    const leaf = keccak256(Buffer.from(address.replace("0x", ""), "hex"));
    return merkleTree.getHexProof(leaf);
  }

  it("Should allow whitelisted address to mint", async function () {
    const proof = getProof(wl1.address);
    await nft.connect(wl1).whitelistMint(proof, { value: ethers.utils.parseEther("0.0005") });
    expect(await nft.ownerOf(1)).to.equal(wl1.address);
  });

  it("Should reject non-whitelisted address", async function () {
    const proof = getProof(wl1.address); // wrong proof for notListed
    await expect(
      nft.connect(notListed).whitelistMint(proof, { value: ethers.utils.parseEther("0.0005") })
    ).to.be.revertedWith("BaseWhitelistNFT: invalid proof");
  });

  it("Should prevent double-minting", async function () {
    const proof = getProof(wl1.address);
    await nft.connect(wl1).whitelistMint(proof, { value: ethers.utils.parseEther("0.0005") });
    await expect(
      nft.connect(wl1).whitelistMint(proof, { value: ethers.utils.parseEther("0.0005") })
    ).to.be.revertedWith("BaseWhitelistNFT: already claimed");
  });

  it("Should reject when whitelist inactive", async function () {
    await nft.connect(owner).setWhitelistActive(false);
    const proof = getProof(wl1.address);
    await expect(
      nft.connect(wl1).whitelistMint(proof, { value: ethers.utils.parseEther("0.0005") })
    ).to.be.revertedWith("BaseWhitelistNFT: whitelist not active");
  });
});
