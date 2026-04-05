const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("BaseNFTMarket", function () {
  let market, nft, owner, seller, buyer;
  const MINT_PRICE = ethers.utils.parseEther("0.001");
  const LIST_PRICE = ethers.utils.parseEther("0.01");

  beforeEach(async function () {
    [owner, seller, buyer] = await ethers.getSigners();

    const BaseERC721 = await ethers.getContractFactory("BaseERC721");
    nft = await BaseERC721.deploy("Test NFT", "TNFT", "ipfs://test/", owner.address, 250);
    await nft.deployed();

    const BaseNFTMarket = await ethers.getContractFactory("BaseNFTMarket");
    market = await BaseNFTMarket.deploy();
    await market.deployed();

    // Owner mints an NFT to seller
    await nft.connect(owner).ownerMint(seller.address, "ipfs://token1");
    // Seller approves market
    await nft.connect(seller).setApprovalForAll(market.address, true);
  });

  describe("Listing", function () {
    it("Should list an NFT", async function () {
      await market.connect(seller).listNFT(nft.address, 1, LIST_PRICE);
      const listing = await market.listings(0);
      expect(listing.seller).to.equal(seller.address);
      expect(listing.price).to.equal(LIST_PRICE);
      expect(listing.active).to.equal(true);
    });

    it("Should reject listing from non-owner", async function () {
      await expect(
        market.connect(buyer).listNFT(nft.address, 1, LIST_PRICE)
      ).to.be.revertedWith("BaseNFTMarket: not owner");
    });
  });

  describe("Buying", function () {
    beforeEach(async function () {
      await market.connect(seller).listNFT(nft.address, 1, LIST_PRICE);
    });

    it("Should transfer NFT to buyer", async function () {
      await market.connect(buyer).buyNFT(0, { value: LIST_PRICE });
      expect(await nft.ownerOf(1)).to.equal(buyer.address);
    });

    it("Should reject insufficient payment", async function () {
      await expect(
        market.connect(buyer).buyNFT(0, { value: ethers.utils.parseEther("0.001") })
      ).to.be.revertedWith("BaseNFTMarket: insufficient payment");
    });

    it("Should deactivate listing after sale", async function () {
      await market.connect(buyer).buyNFT(0, { value: LIST_PRICE });
      const listing = await market.listings(0);
      expect(listing.active).to.equal(false);
    });
  });

  describe("Cancellation", function () {
    it("Should allow seller to cancel", async function () {
      await market.connect(seller).listNFT(nft.address, 1, LIST_PRICE);
      await market.connect(seller).cancelListing(0);
      const listing = await market.listings(0);
      expect(listing.active).to.equal(false);
    });
  });
});
