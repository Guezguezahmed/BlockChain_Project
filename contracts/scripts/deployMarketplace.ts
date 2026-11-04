import { ethers } from "hardhat";

/**
 * Deploys Smart Deal NFT marketplace stack:
 *   SDT (fixed supply) → SmartDealNFT → Marketplace
 *
 * Local:   npx hardhat run scripts/deployMarketplace.ts
 * Sepolia: npm run deploy:marketplace:sepolia
 *
 * Demo faucet: after deploy, the deployer holds the full 10_000_000 SDT supply.
 * Transfer SDT to test wallets (fee 10 + stake 50 per listing, or 5+50 with
 * ≥100 SDT hold discount). There is no on-chain faucet contract — the deploy
 * mint is the faucet for the university demo.
 *
 * Verify (needs ETHERSCAN_API_KEY):
 *   npx hardhat verify --network sepolia <SDT> <DEPLOYER> <SUPPLY>
 *   npx hardhat verify --network sepolia <NFT>
 *   npx hardhat verify --network sepolia <MARKET> <SDT> <FEE> <STAKE> <HOLD> <BPS>
 */
async function main() {
  const [deployer] = await ethers.getSigners();
  const network = await ethers.provider.getNetwork();
  console.log("Network chainId:", network.chainId.toString());
  console.log("Deployer:", deployer.address);

  if (network.chainId === 1n) {
    throw new Error("Refusing to deploy on Ethereum mainnet (Sepolia only).");
  }

  const SDT_SUPPLY = ethers.parseEther("10000000");
  const LISTING_FEE = ethers.parseEther("10");
  const SELLER_STAKE = ethers.parseEther("50");
  const DISCOUNT_HOLD = ethers.parseEther("100");
  const FEE_DISCOUNT_BPS = 5000; // 50%

  const SDT = await ethers.getContractFactory("SDT");
  const sdt = await SDT.deploy(deployer.address, SDT_SUPPLY);
  await sdt.waitForDeployment();
  const sdtAddress = await sdt.getAddress();
  console.log("SDT:", sdtAddress);
  console.log("  supply:", (await sdt.totalSupply()).toString(), "to", deployer.address);

  const NFT = await ethers.getContractFactory("SmartDealNFT");
  const nft = await NFT.deploy();
  await nft.waitForDeployment();
  const nftAddress = await nft.getAddress();
  console.log("SmartDealNFT:", nftAddress);

  const Market = await ethers.getContractFactory("Marketplace");
  const market = await Market.deploy(
    sdtAddress,
    LISTING_FEE,
    SELLER_STAKE,
    DISCOUNT_HOLD,
    FEE_DISCOUNT_BPS
  );
  await market.waitForDeployment();
  const marketAddress = await market.getAddress();
  console.log("Marketplace:", marketAddress);
  console.log("  listingFee:", LISTING_FEE.toString());
  console.log("  sellerStake:", SELLER_STAKE.toString());
  console.log("  discountHoldThreshold:", DISCOUNT_HOLD.toString());
  console.log("  feeDiscountBps:", FEE_DISCOUNT_BPS);

  console.log("\n--- Demo faucet ---");
  console.log(
    "Deployer holds all SDT. Transfer e.g. 200 SDT to a seller wallet for discounted list (fee 5 + stake 50)."
  );
  console.log("Seller must also approve Marketplace for SDT and NFT before listItem.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
