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
  const network = await ethers.provider.getNetwork();
  console.log("Network chainId:", network.chainId.toString());
  console.log("Deployer:", deployer.address);

  if (network.chainId === 1n) {
    throw new Error("Refusing to deploy on Ethereum mainnet (Sepolia only).");
  }

  const Escrow = await ethers.getContractFactory("Escrow");
  const escrowImpl = await Escrow.deploy();
  const escrowTx = escrowImpl.deploymentTransaction();
  console.log("Escrow impl tx:", escrowTx?.hash ?? "(unknown)");
  await escrowImpl.waitForDeployment();
  const escrowImplAddress = await escrowImpl.getAddress();
  console.log("Escrow implementation:", escrowImplAddress);

  const Factory = await ethers.getContractFactory("ContractFactory");
  const factory = await Factory.deploy(escrowImplAddress);
  const factoryTx = factory.deploymentTransaction();
  console.log("Factory tx:", factoryTx?.hash ?? "(unknown)");
  await factory.waitForDeployment();
  const factoryAddress = await factory.getAddress();
  console.log("ContractFactory:", factoryAddress);
  console.log("escrowImplementation():", await factory.escrowImplementation());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
