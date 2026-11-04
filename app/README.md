# Flutter app — Phase 2 MVP

Clean-architecture client for the Escrow preset on **Ethereum Sepolia**.

## App shell (UI)

Bottom navigation keeps the existing teal/sand palette, with frosted (glass) chrome:

| Control | Role |
|---|---|
| **Home** | Brand hero + **Create a contract** CTA + My contracts |
| **+ FAB** (center) | Opens a springy glass create sheet |
| **Profile** | Wallet connect / disconnect (Reown or mock) |

### Create flow (Escrow sur mesure)

1. Tap **Create a contract** (hero) or the center **+**.
2. Sheet shows reorderable template chips (drag handle) + a **Build** drop zone.
3. **Escrow sur mesure (blocks)** opens a Scratch-like canvas: drag plain-English blocks into a stack (seller / amount / deadline + optional story rules). Valid stack → **Deploy** prefills the existing create form (same `createEscrow` params — not a Solidity generator).
4. **Quick Escrow form** or **tap Escrow** opens the classic form. Long-press Escrow → drop on Build also opens the block builder.
5. Form: seller, amount (ETH), deadline → deploy (mock + chain unchanged).

Rental / Milestone are palette **Coming soon** stubs (not buildable). Chain mode (`USE_MOCK=false`) is unchanged.

Screens talk only to `ContractRepository`. Implementations:

| Class | Role |
|---|---|
| `MockContractRepository` | In-memory data (default) — UI without chain |
| `ChainContractRepository` | `web3dart` reads/writes against Sepolia |
| `IndexedContractRepository` | Phase 3 (not implemented) |

Wallet: **Reown AppKit (WalletConnect) → MetaMask**, Sepolia only. Mock mode uses a fake address.

## Live Sepolia deployment (wired)

| Contract | Address |
|---|---|
| **Factory** (`FACTORY_ADDRESS`) | `0x0E847b5Dccd09e73199e3689fC4D0D25A0133F08` |
| Escrow implementation | `0x4bb80444D6669588F7bf1ed6b0EFE71B7Aacf25E` |

Factory Etherscan: https://sepolia.etherscan.io/address/0x0E847b5Dccd09e73199e3689fC4D0D25A0133F08

`AppConfig.factoryAddress` defaults to the live Factory. Mock mode remains the runtime default (`USE_MOCK=true`) so local UI work does not require Reown.

## Prerequisites

- Flutter SDK ≥ 3.8 (`flutter --version`)
- For chain mode: MetaMask (mobile or browser extension), Sepolia ETH
- **Reown Cloud project id** (required for chain mode): https://cloud.reown.com — create a project and copy the Project ID. **Do not invent one.**

## Configure (no secrets in git)

Values are passed with `--dart-define` (or your IDE equivalent). See also repo-root `.env.example`.

| Define | Default | Purpose |
|---|---|---|
| `USE_MOCK` | `true` | Use mock repo + mock wallet. Set `false` for on-chain Sepolia. |
| `FACTORY_ADDRESS` | live Factory above | Sepolia `ContractFactory` |
| `SEPOLIA_RPC_URL` | `https://rpc.sepolia.org` | JSON-RPC (prefer Alchemy Sepolia if you have a key) |
| `WALLETCONNECT_PROJECT_ID` | empty | **Required when `USE_MOCK=false`** — from https://cloud.reown.com |

### Where Ahmed puts the Reown project id

1. Create a project at https://cloud.reown.com and copy the **Project ID**.
2. Pass it only via `--dart-define=WALLETCONNECT_PROJECT_ID=...` (or your IDE Run Configuration / `launch.json` dart-defines).
3. Never commit a real project id into `.env`, source, or this README.

Without this id, chain-mode wallet connect fails with a clear error on the Wallet screen.

## Run (mock — default)

On macOS (preferred for this project):

```bash
cd app
flutter pub get
flutter run -d macos
```

Other devices if you need them:

```bash
flutter run -d ios        # Simulator / device
flutter run -d android
flutter run -d chrome     # optional; needs Flutter web enabled (`flutter config --enable-web`)
```

### iPhone (physical device)

On your Mac (signing / CocoaPods already set up from earlier launches):

```bash
cd ~/Desktop/BlockChain_Project/app   # or your local clone path
git checkout main && git pull
flutter pub get
cd ios && pod install && cd ..
flutter devices                          # note the iPhone id
flutter run -d <IPHONE_DEVICE_ID>       # mock mode by default
```

Smoke-check on iPhone:

1. Home → **Create a contract** (or **+**) → glass sheet.
2. Tap **Escrow sur mesure (blocks)** (or long-press Escrow → drop on Build).
3. Drag: start → Buyer is me → Seller → Lock ETH → Deadline (+ optional outcome story blocks).
4. Tap editable blocks to fill seller / amount / days; **Deploy** when enabled → review form → deploy (mock OK).
5. Confirm Rental / Milestone palette stubs show Coming soon and won’t snap.
6. Also: **Quick Escrow form** still works; Profile → escrow detail links.

Also try: dismiss sheet; reorder chips via the grip icon.

If the icon won’t open: Settings → General → VPN & Device Management → trust the Apple Development cert; enable Developer Mode if prompted.

If you see `No macOS desktop project configured`, pull the latest Phase 2 branch — `app/macos/` is committed. To regenerate platforms without wiping Dart code: `flutter create . --platforms=macos,ios`.

## Run (Sepolia + MetaMask — on-chain)

```bash
cd app
flutter run -d macos \
  --dart-define=USE_MOCK=false \
  --dart-define=FACTORY_ADDRESS=0x0E847b5Dccd09e73199e3689fC4D0D25A0133F08 \
  --dart-define=SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/<YOUR_ALCHEMY_KEY> \
  --dart-define=WALLETCONNECT_PROJECT_ID=<your_reown_project_id>
```

`FACTORY_ADDRESS` may be omitted (defaults to the live Factory). `SEPOLIA_RPC_URL` may stay on the public default if you have no Alchemy key.

Then: Wallet → Connect → MetaMask → Sepolia → Create Escrow → Deposit / Release / Refund.

## Tests

```bash
cd app
flutter test
```

## Layout

```
lib/
  config/           AppConfig (dart-defines + live Sepolia defaults)
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
