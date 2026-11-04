import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import {
  Marketplace,
  SDT,
  SmartDealNFT,
} from "../typechain-types";

const ONE_ETH = ethers.parseEther("1");
const SDT_SUPPLY = ethers.parseEther("10000000");
const LISTING_FEE = ethers.parseEther("10");
const SELLER_STAKE = ethers.parseEther("50");
const DISCOUNT_HOLD = ethers.parseEther("100");
const FEE_DISCOUNT_BPS = 5000n; // 50%
const BURN = "0x000000000000000000000000000000000000dEaD";
const TOKEN_URI = "ipfs://QmSmartDealDemoMetadata";

async function deployFixture() {
  const [deployer, seller, buyer, stranger] = await ethers.getSigners();

  const SDTFactory = await ethers.getContractFactory("SDT");
  const sdt = (await SDTFactory.deploy(
    deployer.address,
    SDT_SUPPLY
  )) as unknown as SDT;
  await sdt.waitForDeployment();

  const NftFactory = await ethers.getContractFactory("SmartDealNFT");
  const nft = (await NftFactory.deploy()) as unknown as SmartDealNFT;
  await nft.waitForDeployment();

  const MarketFactory = await ethers.getContractFactory("Marketplace");
  const market = (await MarketFactory.deploy(
    await sdt.getAddress(),
    LISTING_FEE,
    SELLER_STAKE,
    DISCOUNT_HOLD,
    FEE_DISCOUNT_BPS
  )) as unknown as Marketplace;
  await market.waitForDeployment();

  // Faucet: give seller enough SDT for fee + stake (+ spare for discount tests).
  await sdt.transfer(seller.address, ethers.parseEther("200"));
  await sdt.transfer(buyer.address, ethers.parseEther("50"));

  return { deployer, seller, buyer, stranger, sdt, nft, market };
}

async function mintAndApprove(
  nft: SmartDealNFT,
  sdt: SDT,
  market: Marketplace,
  seller: Awaited<ReturnType<typeof ethers.getSigners>>[0]
) {
  const mintTx = await nft.connect(seller).mint(TOKEN_URI);
  await mintTx.wait();
  const tokenId = (await nft.nextTokenId()) - 1n;

  await nft.connect(seller).approve(await market.getAddress(), tokenId);
  await sdt
    .connect(seller)
    .approve(await market.getAddress(), ethers.parseEther("1000"));

  return tokenId;
}

describe("SDT", () => {
  it("mints fixed supply to initial holder and has no further mint", async () => {
    const { deployer, sdt } = await loadFixture(deployFixture);
    expect(await sdt.name()).to.equal("Smart Deal Token");
    expect(await sdt.symbol()).to.equal("SDT");
    expect(await sdt.totalSupply()).to.equal(SDT_SUPPLY);
    // Deployer received supply then transferred some to seller/buyer in fixture.
    expect(await sdt.balanceOf(deployer.address)).to.equal(
      SDT_SUPPLY - ethers.parseEther("250")
    );
  });
});

describe("SmartDealNFT", () => {
  it("lets a user mint with tokenURI", async () => {
    const { seller, nft } = await loadFixture(deployFixture);
    await expect(nft.connect(seller).mint(TOKEN_URI))
      .to.emit(nft, "NFTMinted")
      .withArgs(seller.address, 1n, TOKEN_URI);
    expect(await nft.ownerOf(1n)).to.equal(seller.address);
    expect(await nft.tokenURI(1n)).to.equal(TOKEN_URI);
  });

  it("reverts on empty URI", async () => {
    const { seller, nft } = await loadFixture(deployFixture);
    await expect(nft.connect(seller).mint("")).to.be.revertedWithCustomError(
      nft,
      "EmptyURI"
    );
  });
});

describe("Marketplace", () => {
  describe("listItem", () => {
    it("lists NFT, burns fee, locks stake, custodians NFT", async () => {
      const { seller, sdt, nft, market } = await loadFixture(deployFixture);
      const tokenId = await mintAndApprove(nft, sdt, market, seller);
      const marketAddr = await market.getAddress();

      const sellerBefore = await sdt.balanceOf(seller.address);
      const burnBefore = await sdt.balanceOf(BURN);

      await expect(market.connect(seller).listItem(await nft.getAddress(), tokenId, ONE_ETH))
        .to.emit(market, "ItemListed");

      const listing = await market.getListing(1n);
      expect(listing.seller).to.equal(seller.address);
      expect(listing.nft).to.equal(await nft.getAddress());
      expect(listing.tokenId).to.equal(tokenId);
      expect(listing.priceWei).to.equal(ONE_ETH);
      expect(listing.active).to.equal(true);
      expect(listing.stakeLocked).to.equal(SELLER_STAKE);
      // Seller holds 200 SDT >= 100 → 50% fee discount → 5 SDT burned
      expect(listing.feePaid).to.equal(LISTING_FEE / 2n);

      expect(await nft.ownerOf(tokenId)).to.equal(marketAddr);
      expect(await market.lockedStake(seller.address)).to.equal(SELLER_STAKE);
      expect(await sdt.balanceOf(BURN)).to.equal(burnBefore + LISTING_FEE / 2n);
      expect(await sdt.balanceOf(seller.address)).to.equal(
        sellerBefore - LISTING_FEE / 2n - SELLER_STAKE
      );
      expect(await sdt.balanceOf(marketAddr)).to.equal(SELLER_STAKE);
    });

    it("charges full fee when seller holds below discount threshold and has no stake", async () => {
      const { deployer, stranger, sdt, nft, market } = await loadFixture(
        deployFixture
      );
      // Stranger gets only fee+stake worth of SDT (60), below 100 threshold.
      await sdt.connect(deployer).transfer(stranger.address, ethers.parseEther("60"));
      const tokenId = await mintAndApprove(nft, sdt, market, stranger);

      await market
        .connect(stranger)
        .listItem(await nft.getAddress(), tokenId, ONE_ETH);

      const listing = await market.getListing(1n);
      expect(listing.feePaid).to.equal(LISTING_FEE);
      expect(await sdt.balanceOf(BURN)).to.equal(LISTING_FEE);
    });

    it("reverts when caller does not own the NFT", async () => {
      const { seller, buyer, sdt, nft, market } = await loadFixture(deployFixture);
      const tokenId = await mintAndApprove(nft, sdt, market, seller);
      await sdt.connect(buyer).approve(await market.getAddress(), ethers.parseEther("1000"));

      await expect(
        market.connect(buyer).listItem(await nft.getAddress(), tokenId, ONE_ETH)
      ).to.be.revertedWithCustomError(market, "NotNftOwner");
    });

    it("reverts on zero price", async () => {
      const { seller, sdt, nft, market } = await loadFixture(deployFixture);
      const tokenId = await mintAndApprove(nft, sdt, market, seller);
      await expect(
        market.connect(seller).listItem(await nft.getAddress(), tokenId, 0)
      ).to.be.revertedWithCustomError(market, "InvalidPrice");
    });
  });

  describe("buyItem", () => {
    it("transfers NFT to buyer, ETH to seller, unlocks stake", async () => {
      const { seller, buyer, sdt, nft, market } = await loadFixture(deployFixture);
      const tokenId = await mintAndApprove(nft, sdt, market, seller);
      await market
        .connect(seller)
        .listItem(await nft.getAddress(), tokenId, ONE_ETH);

      const sellerEthBefore = await ethers.provider.getBalance(seller.address);
      const sellerSdtBefore = await sdt.balanceOf(seller.address);

      await expect(market.connect(buyer).buyItem(1n, { value: ONE_ETH })).to.emit(
        market,
        "ItemSold"
      );

      expect(await nft.ownerOf(tokenId)).to.equal(buyer.address);
      expect((await market.getListing(1n)).active).to.equal(false);
      expect(await market.lockedStake(seller.address)).to.equal(0n);
      expect(await sdt.balanceOf(seller.address)).to.equal(
        sellerSdtBefore + SELLER_STAKE
      );
      expect(await ethers.provider.getBalance(seller.address)).to.equal(
        sellerEthBefore + ONE_ETH
      );
    });

    it("reverts on wrong ETH amount", async () => {
      const { seller, buyer, sdt, nft, market } = await loadFixture(deployFixture);
      const tokenId = await mintAndApprove(nft, sdt, market, seller);
      await market
        .connect(seller)
        .listItem(await nft.getAddress(), tokenId, ONE_ETH);

      await expect(
        market.connect(buyer).buyItem(1n, { value: ethers.parseEther("0.5") })
      ).to.be.revertedWithCustomError(market, "IncorrectPayment");
    });

    it("reverts when seller tries to buy own listing", async () => {
      const { seller, sdt, nft, market } = await loadFixture(deployFixture);
      const tokenId = await mintAndApprove(nft, sdt, market, seller);
      await market
        .connect(seller)
        .listItem(await nft.getAddress(), tokenId, ONE_ETH);

      await expect(
        market.connect(seller).buyItem(1n, { value: ONE_ETH })
      ).to.be.revertedWithCustomError(market, "CannotBuyOwnListing");
    });
  });

  describe("cancelListing", () => {
    it("returns NFT and stake to seller", async () => {
      const { seller, sdt, nft, market } = await loadFixture(deployFixture);
      const tokenId = await mintAndApprove(nft, sdt, market, seller);
      await market
        .connect(seller)
        .listItem(await nft.getAddress(), tokenId, ONE_ETH);

      const sdtBefore = await sdt.balanceOf(seller.address);
      await expect(market.connect(seller).cancelListing(1n))
        .to.emit(market, "ListingCancelled");

      expect(await nft.ownerOf(tokenId)).to.equal(seller.address);
      expect((await market.getListing(1n)).active).to.equal(false);
      expect(await market.lockedStake(seller.address)).to.equal(0n);
      expect(await sdt.balanceOf(seller.address)).to.equal(sdtBefore + SELLER_STAKE);
      // Fee stays burned
      expect(await sdt.balanceOf(BURN)).to.equal(LISTING_FEE / 2n);
    });

    it("reverts if non-seller cancels", async () => {
      const { seller, buyer, sdt, nft, market } = await loadFixture(deployFixture);
      const tokenId = await mintAndApprove(nft, sdt, market, seller);
      await market
        .connect(seller)
        .listItem(await nft.getAddress(), tokenId, ONE_ETH);

      await expect(
        market.connect(buyer).cancelListing(1n)
      ).to.be.revertedWithCustomError(market, "NotSeller");
    });

    it("reverts if listing already sold", async () => {
      const { seller, buyer, sdt, nft, market } = await loadFixture(deployFixture);
      const tokenId = await mintAndApprove(nft, sdt, market, seller);
      await market
        .connect(seller)
        .listItem(await nft.getAddress(), tokenId, ONE_ETH);
      await market.connect(buyer).buyItem(1n, { value: ONE_ETH });

      await expect(
        market.connect(seller).cancelListing(1n)
      ).to.be.revertedWithCustomError(market, "ListingNotActive");
    });
  });

  describe("quoteListingFee", () => {
    it("quotes discounted fee when balance >= threshold", async () => {
      const { seller, market } = await loadFixture(deployFixture);
      expect(await market.quoteListingFee(seller.address)).to.equal(
        LISTING_FEE / 2n
      );
    });

    it("quotes full fee below threshold with no locked stake", async () => {
      const { buyer, market } = await loadFixture(deployFixture);
      // buyer has 50 SDT
      expect(await market.quoteListingFee(buyer.address)).to.equal(LISTING_FEE);
    });
  });
});
