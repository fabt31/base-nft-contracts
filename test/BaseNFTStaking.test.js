const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("BaseNFTStaking", function () {
  let staking, nft, rewardToken, owner, user1;
  const ONE_DAY = 86400;
  const REWARD_PER_DAY = ethers.utils.parseEther("10");

  beforeEach(async function () {
    [owner, user1] = await ethers.getSigners();

    const BaseERC721 = await ethers.getContractFactory("BaseERC721");
    nft = await BaseERC721.deploy("Stake NFT", "SNFT", "ipfs://", owner.address, 0);
    await nft.deployed();

    const BaseToken = await ethers.getContractFactory("BaseToken");
    rewardToken = await BaseToken.deploy();
    await rewardToken.deployed();

    const BaseNFTStaking = await ethers.getContractFactory("BaseNFTStaking");
    staking = await BaseNFTStaking.deploy(nft.address, rewardToken.address, REWARD_PER_DAY);
    await staking.deployed();

    // Fund staking with rewards
    await rewardToken.mint(staking.address, ethers.utils.parseEther("1000000"));

    // Mint NFT to user
    await nft.connect(owner).ownerMint(user1.address, "ipfs://nft1");
    await nft.connect(user1).setApprovalForAll(staking.address, true);
  });

  it("Should stake an NFT", async function () {
    await staking.connect(user1).stake(1);
    const info = await staking.stakes(1);
    expect(info.owner).to.equal(user1.address);
  });

  it("Should accumulate rewards over time", async function () {
    await staking.connect(user1).stake(1);
    await time.increase(ONE_DAY);
    const pending = await staking.pendingRewards(1);
    expect(pending).to.be.closeTo(REWARD_PER_DAY, ethers.utils.parseEther("0.01"));
  });

  it("Should unstake and receive rewards", async function () {
    await staking.connect(user1).stake(1);
    await time.increase(ONE_DAY);
    const balBefore = await rewardToken.balanceOf(user1.address);
    await staking.connect(user1).unstake(1);
    const balAfter = await rewardToken.balanceOf(user1.address);
    expect(balAfter).to.be.gt(balBefore);
    expect(await nft.ownerOf(1)).to.equal(user1.address);
  });

  it("Should reject unstake from non-staker", async function () {
    await staking.connect(user1).stake(1);
    await expect(staking.connect(owner).unstake(1)).to.be.revertedWith("BaseNFTStaking: not staker");
  });
});
