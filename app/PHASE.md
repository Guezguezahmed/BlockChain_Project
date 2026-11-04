# App — Smart Deal marketplace (v0.5)

Implemented:

- **Primary product:** peer NFT marketplace on Sepolia (SDT fee + stake, ETH buy, ownership transfer)
- Clean architecture: `presentation` / `domain` / `data`
- `MarketplaceRepository` + mock + chain (Marketplace / SDT / SmartDealNFT ABIs)
- `ContractRepository` kept for advanced custom Escrow path
- Wallet: Reown AppKit → MetaMask, Sepolia only; mock wallet for UI / tests
- Screens: Home (listings), Mint NFT, List NFT, Listing detail (buy/cancel), Profile (+ SDT faucet note); Escrow create/detail still available from create sheet
- Config via `--dart-define` (`SDT_ADDRESS`, `NFT_ADDRESS`, `MARKETPLACE_ADDRESS`, `FACTORY_ADDRESS`, `SEPOLIA_RPC_URL`, `WALLETCONNECT_PROJECT_ID`, `USE_MOCK`)
- Live defaults wired to Sepolia deploy from docs/sepolia-smart-deal-addresses.md

Not in this phase: Nest/Mongo indexer, physical goods, contract redeploys.
