import { ethers } from "hardhat";

/**
 * Deploys the Escrow implementation + ContractFactory.
 *
 * Local:  npx hardhat run scripts/deploy.ts
 * Sepolia: set SEPOLIA_RPC_URL + SEPOLIA_PRIVATE_KEY in .env, then
 *          npm run deploy:sepolia
 * Afterwards verify with hardhat-verify (needs ETHERSCAN_API_KEY):
 *   npx hardhat verify --network sepolia <ESCROW_IMPL>
 *   npx hardhat verify --network sepolia <FACTORY> <ESCROW_IMPL>
 */
async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  const Escrow = await ethers.getContractFactory("Escrow");
  const escrowImpl = await Escrow.deploy();
  await escrowImpl.waitForDeployment();
  const escrowImplAddress = await escrowImpl.getAddress();
  console.log("Escrow implementation:", escrowImplAddress);

  const Factory = await ethers.getContractFactory("ContractFactory");
  const factory = await Factory.deploy(escrowImplAddress);
  await factory.waitForDeployment();
  const factoryAddress = await factory.getAddress();
  console.log("ContractFactory:", factoryAddress);
  console.log("escrowImplementation():", await factory.escrowImplementation());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
