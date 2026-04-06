const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("BaseLazyMint", function () {
  let lazyMint, owner, minter, buyer;
  const MINT_PRICE = ethers.parseEther("0.01");

  beforeEach(async function () {
    [owner, minter, buyer] = await ethers.getSigners();
    const LazyMint = await ethers.getContractFactory("BaseLazyMint");
    lazyMint = await LazyMint.deploy(
      "LazyNFT",
      "LAZY",
      owner.address  // royalty receiver
    );
  });

  async function signVoucher(signer, tokenId, minPrice, uri) {
    const domain = {
      name: "LazyNFT",
      version: "1",
      chainId: (await ethers.provider.getNetwork()).chainId,
      verifyingContract: await lazyMint.getAddress()
    };
    const types = {
      NFTVoucher: [
        { name: "tokenId",  type: "uint256" },
        { name: "minPrice", type: "uint256" },
        { name: "uri",      type: "string"  }
      ]
    };
    const voucher = { tokenId, minPrice, uri };
    const signature = await signer.signTypedData(domain, types, voucher);
    return { tokenId, minPrice, uri, signature };
  }

  it("should redeem a valid voucher", async function () {
    const uri = "ipfs://QmTest123";
    const voucher = await signVoucher(owner, 1, MINT_PRICE, uri);

    await lazyMint.connect(buyer).redeem(buyer.address, voucher, { value: MINT_PRICE });

    expect(await lazyMint.ownerOf(1)).to.equal(buyer.address);
    expect(await lazyMint.tokenURI(1)).to.equal(uri);
  });

  it("should reject voucher with insufficient payment", async function () {
    const voucher = await signVoucher(owner, 2, MINT_PRICE, "ipfs://QmTest456");
    await expect(
      lazyMint.connect(buyer).redeem(buyer.address, voucher, { value: ethers.parseEther("0.001") })
    ).to.be.revertedWith("Insufficient payment");
  });

  it("should reject voucher with invalid signature", async function () {
    const voucher = await signVoucher(minter, 3, MINT_PRICE, "ipfs://QmTest789");
    await expect(
      lazyMint.connect(buyer).redeem(buyer.address, voucher, { value: MINT_PRICE })
    ).to.be.revertedWith("Invalid signature");
  });

  it("should prevent replaying a voucher", async function () {
    const voucher = await signVoucher(owner, 4, MINT_PRICE, "ipfs://QmTestABC");
    await lazyMint.connect(buyer).redeem(buyer.address, voucher, { value: MINT_PRICE });
    await expect(
      lazyMint.connect(buyer).redeem(buyer.address, voucher, { value: MINT_PRICE })
    ).to.be.reverted;
  });

  it("owner should be able to withdraw proceeds", async function () {
    const voucher = await signVoucher(owner, 5, MINT_PRICE, "ipfs://QmTestDEF");
    await lazyMint.connect(buyer).redeem(buyer.address, voucher, { value: MINT_PRICE });

    const balanceBefore = await ethers.provider.getBalance(owner.address);
    const tx = await lazyMint.connect(owner).withdraw();
    const receipt = await tx.wait();
    const gasUsed = receipt.gasUsed * receipt.gasPrice;
    const balanceAfter = await ethers.provider.getBalance(owner.address);

    expect(balanceAfter + gasUsed).to.be.gt(balanceBefore);
  });
});
