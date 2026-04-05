const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("BaseERC721", function () {
  let nft, owner, user1, user2;
  const MINT_PRICE = ethers.utils.parseEther("0.001");
  const ROYALTY_BPS = 500; // 5%

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();
    const BaseERC721 = await ethers.getContractFactory("BaseERC721");
    nft = await BaseERC721.deploy(
      "Base Genesis NFT",
      "BGNFT",
      "ipfs://QmBase/",
      owner.address,
      ROYALTY_BPS
    );
    await nft.deployed();
  });

  describe("Deployment", function () {
    it("Should set correct name and symbol", async function () {
      expect(await nft.name()).to.equal("Base Genesis NFT");
      expect(await nft.symbol()).to.equal("BGNFT");
    });

    it("Should start with minting inactive", async function () {
      expect(await nft.mintingActive()).to.equal(false);
    });

    it("Should set correct royalty", async function () {
      const [receiver, amount] = await nft.royaltyInfo(1, 10000);
      expect(receiver).to.equal(owner.address);
      expect(amount).to.equal(500); // 5%
    });
  });

  describe("Minting", function () {
    beforeEach(async function () {
      await nft.connect(owner).toggleMinting();
    });

    it("Should mint with correct payment", async function () {
      await nft.connect(user1).mint("ipfs://token1", { value: MINT_PRICE });
      expect(await nft.ownerOf(1)).to.equal(user1.address);
    });

    it("Should reject mint when minting inactive", async function () {
      await nft.connect(owner).toggleMinting(); // toggle off
      await expect(
        nft.connect(user1).mint("ipfs://token1", { value: MINT_PRICE })
      ).to.be.revertedWith("BaseERC721: minting not active");
    });

    it("Should reject insufficient payment", async function () {
      await expect(
        nft.connect(user1).mint("ipfs://token1", { value: ethers.utils.parseEther("0.0001") })
      ).to.be.revertedWith("BaseERC721: insufficient payment");
    });

    it("Should allow owner to mint without restriction", async function () {
      await nft.connect(owner).toggleMinting(); // toggle off
      await nft.connect(owner).ownerMint(user1.address, "ipfs://admin");
      expect(await nft.ownerOf(1)).to.equal(user1.address);
    });
  });

  describe("Withdraw", function () {
    it("Should allow owner to withdraw proceeds", async function () {
      await nft.connect(owner).toggleMinting();
      await nft.connect(user1).mint("ipfs://t1", { value: MINT_PRICE });
      const before = await ethers.provider.getBalance(owner.address);
      await nft.connect(owner).withdraw();
      const after = await ethers.provider.getBalance(owner.address);
      expect(after).to.be.gt(before);
    });
  });
});
