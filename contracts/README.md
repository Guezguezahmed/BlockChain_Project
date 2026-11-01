# Contracts (Hardhat)

Escrow template + `ContractFactory` (EIP-1167 clones). Shared ABI surface: `contracts/interfaces/IContracts.sol`.

## Setup

```bash
cd contracts
npm install
cp ../.env.example ../.env   # only needed for Sepolia deploy/verify
```

## Test (local, no RPC secrets required)

```bash
cd contracts
npm test
# or: npx hardhat test
```

Coverage:

```bash
npx hardhat coverage
```

## Deploy

Local (in-process Hardhat network):

```bash
npm run deploy:local
```

Sepolia (requires `SEPOLIA_RPC_URL` + `SEPOLIA_PRIVATE_KEY` in repo-root `.env`):

```bash
npm run deploy:sepolia
```

Verify on Etherscan (requires `ETHERSCAN_API_KEY`):

```bash
npx hardhat verify --network sepolia <ESCROW_IMPLEMENTATION_ADDRESS>
npx hardhat verify --network sepolia <FACTORY_ADDRESS> <ESCROW_IMPLEMENTATION_ADDRESS>
```

Phase 0/1 prefers local tests; Sepolia deploy is optional until secrets/RPC are available.
