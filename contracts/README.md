# Contracts (Hardhat)

Two paths live here:

1. **Smart Deal NFT Marketplace (primary MVP)** — `SDT` + `SmartDealNFT` + `Marketplace`
2. **Escrow + Factory (legacy / optional)** — EIP-1167 clones; still tested, not the main demo path

Shared ABI surface: `contracts/interfaces/IContracts.sol`.

## Smart Deal marketplace (professor pivot)

Buyers pay listing price in **ETH**. Sellers pay **SDT** listing fee (burned) + lock an **SDT** stake. Digital NFTs only: mint on `SmartDealNFT`, list on `Marketplace`, buy transfers NFT ownership.

| Parameter | Demo default |
|-----------|--------------|
| SDT supply | 10_000_000 (minted once to deployer) |
| Listing fee | 10 SDT (burned to `0x…dEaD`) |
| Seller stake | 50 SDT (locked while listed; returned on buy or cancel) |
| Fee discount | 50% if seller holds ≥100 SDT **or** already has stake locked |

**SDT mint choice:** constructor mints the full fixed supply to the deployer. There is no Ownable / ongoing mint — supply cannot be inflated after deploy.

**NFT custody:** on `listItem`, the NFT is transferred into the Marketplace. On `buyItem` it goes to the buyer; on `cancelListing` it returns to the seller. No admin withdraw.

### Demo faucet (SDT)

There is no on-chain faucet contract. After deploy, the **deployer holds all SDT**. For a two-wallet demo:

1. Transfer ~200 SDT from deployer → seller (enough for discounted fee + stake).
2. Seller `mint`s an NFT on `SmartDealNFT`, then `approve`s Marketplace for the NFT and SDT.
3. Seller calls `listItem(nft, tokenId, priceWei)`.
4. Buyer calls `buyItem(listingId)` with exact ETH.

```bash
npm run deploy:marketplace:local
# or: npm run deploy:marketplace:sepolia
```

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

### Marketplace (primary)

```bash
npm run deploy:marketplace:local
# Sepolia (needs SEPOLIA_RPC_URL + SEPOLIA_PRIVATE_KEY):
npm run deploy:marketplace:sepolia
```

Mainnet guard: scripts refuse `chainId === 1`.

### Escrow + Factory (legacy)

```bash
npm run deploy:local
npm run deploy:sepolia
```

Verify on Etherscan (requires `ETHERSCAN_API_KEY`):

```bash
npx hardhat verify --network sepolia <SDT_ADDRESS> <DEPLOYER> 10000000000000000000000000
npx hardhat verify --network sepolia <NFT_ADDRESS>
npx hardhat verify --network sepolia <MARKET_ADDRESS> <SDT> <FEE> <STAKE> <HOLD> <BPS>
```
