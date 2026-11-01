# Flutter app — Phase 2 MVP

Clean-architecture client for the Escrow preset on **Ethereum Sepolia**.

Screens talk only to `ContractRepository`. Implementations:

| Class | Role |
|---|---|
| `MockContractRepository` | In-memory data (default) — UI without chain |
| `ChainContractRepository` | `web3dart` reads/writes against Sepolia |
| `IndexedContractRepository` | Phase 3 (not implemented) |

Wallet: **Reown AppKit (WalletConnect) → MetaMask**, Sepolia only. Mock mode uses a fake address.

## Prerequisites

- Flutter SDK ≥ 3.8 (`flutter --version`)
- For chain mode: MetaMask (mobile or browser extension), Sepolia ETH, deployed `ContractFactory`
- Reown Cloud project id: https://cloud.reown.com

## Configure (no secrets in git)

Values are passed with `--dart-define` (or your IDE equivalent). See also repo-root `.env.example` for Hardhat deploy vars.

| Define | Default | Purpose |
|---|---|---|
| `USE_MOCK` | `true` | Use mock repo + mock wallet |
| `FACTORY_ADDRESS` | empty | Sepolia `ContractFactory` address **after deploy** |
| `SEPOLIA_RPC_URL` | `https://rpc.sepolia.org` | JSON-RPC |
| `WALLETCONNECT_PROJECT_ID` | empty | Reown / WalletConnect project id |

**Do not invent a factory address.** Deploy from `contracts/` first:

```bash
cd contracts
cp ../.env.example ../.env   # fill SEPOLIA_RPC_URL + SEPOLIA_PRIVATE_KEY
npm run deploy:sepolia
# copy printed ContractFactory address into FACTORY_ADDRESS
```

## Run (mock — default)

```bash
cd app
flutter pub get
flutter run -d chrome
# or: flutter run -d android / ios / linux
```

## Run (Sepolia + MetaMask)

```bash
cd app
flutter run -d chrome \
  --dart-define=USE_MOCK=false \
  --dart-define=FACTORY_ADDRESS=0xYourFactoryAddress \
  --dart-define=SEPOLIA_RPC_URL=https://rpc.sepolia.org \
  --dart-define=WALLETCONNECT_PROJECT_ID=your_reown_project_id
```

Then: Wallet → Connect → MetaMask → Sepolia → Create Escrow → Deposit / Release / Refund.

## Tests

```bash
cd app
flutter test
```

## Layout

```
lib/
  config/           AppConfig (dart-defines)
  domain/           models, ContractRepository, WalletService
  data/
    abis/           Factory + Escrow ABI JSON (from Hardhat artifacts)
    repositories/   Mock + Chain
    wallet/         Mock + Reown AppKit
  presentation/     Riverpod providers, screens, widgets
```

## What’s next

- **Phase 3**: NestJS indexer + `IndexedContractRepository` with chain fallback
- **Phase 4**: Explore page + richer tx status UI
