# Flutter app — Smart Deal marketplace (Sepolia)

Peer-to-peer **NFT marketplace** client. Sellers pay **SDT** listing fee + stake; buyers pay **ETH**; NFT ownership transfers on purchase. Custom Escrow remains available as an advanced path.

## App shell (UI)

Bottom navigation keeps the teal/sand glass chrome:

| Control | Role |
|---|---|
| **Market** | Smart Deal hero + NFT card grid (image, title, ETH, seller) |
| **My Items** | Owned NFTs + my listings inventory |
| **+ FAB** (center) | Mint → approve SDT/NFT → list (Escrow under Advanced) |
| **Profile** | Wallet connect, SDT balance, faucet note |

### Primary flow (MVP)

1. Connect wallet (Profile) on Sepolia.
2. **Mint demo NFT** (or use one you already own on SmartDealNFT).
3. **Approve SDT** (fee + stake) → **Approve NFT** → **List for ETH**.
4. Another wallet browses Home → opens listing → **Buy** with exact ETH.
5. Detail screen shows ownership change + Etherscan tx links.

Demo SDT: fixed supply was minted to the deployer. Sellers need fee+stake (`10 + 50` SDT, or `5 + 50` with ≥100 SDT hold discount). Profile / list screens explain how to get demo SDT.

Screens talk only to repositories (`ContractRepository` + `MarketplaceRepository`).

## Live Sepolia deployment (wired defaults)

| Contract | Address |
|---|---|
| **SDT** | `0x6dBA1A76E8fAF697b8E4392b565021fd0038C0Ab` |
| **SmartDealNFT** | `0x14D7811438c6638096BfefB029A22CBeAEF86F57` |
| **Marketplace** | `0x910e480723a0Ed7bf7f22d5e01CcF8db2E2fA97B` |
| Factory (Escrow advanced) | `0x0E847b5Dccd09e73199e3689fC4D0D25A0133F08` |

Mock mode remains the runtime default (`USE_MOCK=true`).

## Prerequisites

- Flutter SDK ≥ 3.8
- Chain mode: MetaMask + Sepolia ETH + Reown project id from https://cloud.reown.com

## Configure (`--dart-define`)

| Define | Default | Purpose |
|---|---|---|
| `USE_MOCK` | `true` | Mock repos + mock wallet |
| `SDT_ADDRESS` | live SDT | Smart Deal Token |
| `NFT_ADDRESS` | live NFT | SmartDealNFT |
| `MARKETPLACE_ADDRESS` | live Marketplace | listings |
| `FACTORY_ADDRESS` | live Factory | Escrow advanced path |
| `SEPOLIA_RPC_URL` | `https://rpc.sepolia.org` | Prefer Alchemy if you have a key |
| `WALLETCONNECT_PROJECT_ID` | empty | **Required when `USE_MOCK=false`** |

## Run (mock — default)

```bash
cd app
flutter pub get
flutter run -d chrome    # or ios / macos
```

## Run on Chrome (Sepolia + MetaMask)

```bash
cd app
flutter run -d chrome \
  --dart-define=USE_MOCK=false \
  --dart-define=SDT_ADDRESS=0x6dBA1A76E8fAF697b8E4392b565021fd0038C0Ab \
  --dart-define=NFT_ADDRESS=0x14D7811438c6638096BfefB029A22CBeAEF86F57 \
  --dart-define=MARKETPLACE_ADDRESS=0x910e480723a0Ed7bf7f22d5e01CcF8db2E2fA97B \
  --dart-define=FACTORY_ADDRESS=0x0E847b5Dccd09e73199e3689fC4D0D25A0133F08 \
  --dart-define=SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/<YOUR_ALCHEMY_KEY> \
  --dart-define=WALLETCONNECT_PROJECT_ID=<your_reown_project_id>
```

Marketplace addresses may be omitted (they match the live defaults above).

## Run on iPhone

```bash
cd app
git checkout main && git pull   # or this PR branch
flutter pub get
cd ios && pod install && cd ..
flutter devices
flutter run -d <IPHONE_DEVICE_ID> \
  --dart-define=USE_MOCK=false \
  --dart-define=SDT_ADDRESS=0x6dBA1A76E8fAF697b8E4392b565021fd0038C0Ab \
  --dart-define=NFT_ADDRESS=0x14D7811438c6638096BfefB029A22CBeAEF86F57 \
  --dart-define=MARKETPLACE_ADDRESS=0x910e480723a0Ed7bf7f22d5e01CcF8db2E2fA97B \
  --dart-define=SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/<YOUR_ALCHEMY_KEY> \
  --dart-define=WALLETCONNECT_PROJECT_ID=<your_reown_project_id>
```

Smoke-check: Profile → Connect → Mint → Approve SDT → Approve NFT → List → (second wallet) Buy → ownership updates on detail.

## Tests

```bash
cd app
flutter test
```

## Layout

```
lib/
  config/           AppConfig (marketplace + factory dart-defines)
  domain/           escrow + marketplace models / repos
  data/
    abis/           Factory, Escrow, Marketplace, SDT, SmartDealNFT
    repositories/   Mock + Chain (escrow + marketplace)
    wallet/         Mock + Reown AppKit
  presentation/     Home marketplace, mint/list/detail, Escrow advanced
```

## What’s next

- Richer NFT metadata rendering (IPFS images)
- Optional Nest indexer (skipped for uni demo unless asked)
