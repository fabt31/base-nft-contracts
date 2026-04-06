const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("BaseNFTAuction", function () {
  let auction, nft, owner, seller, bidder1, bidder2;
  const START_PRICE = ethers.parseEther("0.1");
  const ONE_DAY = 24 * 3600;

  beforeEach(async function () {
    [owner, seller, bidder1, bidder2] = await ethers.getSigners();
    const NFT = await ethers.getContractFactory("BaseERC721");
    nft = await NFT.deploy("TestNFT", "TNFT", ethers.parseEther("0.05"), 100, seller.address, 500);

    const Auction = await ethers.getContractFactory("BaseNFTAuction");
    auction = await Auction.deploy();

    // Seller mints an NFT
    await nft.connect(seller).mint(1, { value: ethers.parseEther("0.05") });
    await nft.connect(seller).approve(await auction.getAddress(), 1);
  });

  it("should create an auction", async function () {
    const tx = await auction.connect(seller).createAuction(
      await nft.getAddress(), 1, START_PRICE, 0, ONE_DAY
    );
    await tx.wait();
    const a = await auction.auctions(0);
    expect(a.seller).to.equal(seller.address);
    expect(a.highestBid).to.equal(0);
    expect(a.settled).to.be.false;
  });

  it("should accept a valid bid", async function () {
    await auction.connect(seller).createAuction(await nft.getAddress(), 1, START_PRICE, 0, ONE_DAY);
    await auction.connect(bidder1).bid(0, { value: START_PRICE });
    const a = await auction.auctions(0);
    expect(a.highestBidder).to.equal(bidder1.address);
    expect(a.highestBid).to.equal(START_PRICE);
  });

  it("should outbid previous bidder and refund them", async function () {
    await auction.connect(seller).createAuction(await nft.getAddress(), 1, START_PRICE, 0, ONE_DAY);
    await auction.connect(bidder1).bid(0, { value: START_PRICE });
    const higher = ethers.parseEther("0.2");
    await auction.connect(bidder2).bid(0, { value: higher });

    const a = await auction.auctions(0);
    expect(a.highestBidder).to.equal(bidder2.address);
    expect(await auction.pendingWithdrawals(bidder1.address)).to.equal(START_PRICE);
  });

  it("should settle auction and transfer NFT to winner", async function () {
    await auction.connect(seller).createAuction(await nft.getAddress(), 1, START_PRICE, 0, ONE_DAY);
    await auction.connect(bidder1).bid(0, { value: START_PRICE });

    await time.increase(ONE_DAY + 1);
    await auction.settleAuction(0);

    expect(await nft.ownerOf(1)).to.equal(bidder1.address);
    const a = await auction.auctions(0);
    expect(a.settled).to.be.true;
  });

  it("should reject bid below start price", async function () {
    await auction.connect(seller).createAuction(await nft.getAddress(), 1, START_PRICE, 0, ONE_DAY);
    await expect(
      auction.connect(bidder1).bid(0, { value: ethers.parseEther("0.001") })
    ).to.be.revertedWith("Below start price");
  });

  it("should reject settle before auction ends", async function () {
    await auction.connect(seller).createAuction(await nft.getAddress(), 1, START_PRICE, 0, ONE_DAY);
    await expect(auction.settleAuction(0)).to.be.revertedWith("Auction not ended");
  });
});
