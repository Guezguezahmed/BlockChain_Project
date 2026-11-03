# BlockChain_Project

Decentralized, no-code smart contract builder (university project). Users configure presets (starting with **Escrow**) and deploy real contracts on **Ethereum Sepolia**. No owner, no admin, no fees — the chain is the source of truth.

Full rules and roadmap: [`AGENTS.md`](./AGENTS.md).

## Monorepo layout

| Path | Role |
|---|---|
| `contracts/` | Hardhat (Solidity ^0.8.24, ethers.js, OpenZeppelin) |
| `backend/` | NestJS indexer + read-only REST (Phase 3 — not started) |
| `app/` | Flutter client (Phase 2 MVP) |
| `docs/` | Write-up / diagrams |
| `AGENTS.md` | Project brief (source of truth for assistants) |

## Phase status

- **Phase 0–1**: Escrow + `ContractFactory`, Hardhat tests, monorepo scaffold
- **Phase 2 (current)**: Flutter MVP — wallet connect, Escrow form, My Contracts, detail actions via `ChainContractRepository` / mock
- **Sepolia**: Factory `0x0E847b5Dccd09e73199e3689fC4D0D25A0133F08` (Escrow impl `0x4bb80444D6669588F7bf1ed6b0EFE71B7Aacf25E`) — Flutter chain mode wired; needs your Reown project id
- **Not started**: Phase 3 indexer, Phase 4 Explore

### Run contract tests

```bash
cd contracts
npm install
npm test
```

### Run Flutter app (mock by default)

```bash
cd app
flutter pub get
flutter run -d macos
```

Chrome is optional (`flutter run -d chrome` if web is enabled). See [`app/README.md`](./app/README.md) for Sepolia + MetaMask (`USE_MOCK=false`, `WALLETCONNECT_PROJECT_ID`).

### Run Flutter against live Sepolia

```bash
cd app
flutter run -d macos \
  --dart-define=USE_MOCK=false \
  --dart-define=FACTORY_ADDRESS=0x0E847b5Dccd09e73199e3689fC4D0D25A0133F08 \
  --dart-define=SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/<YOUR_ALCHEMY_KEY> \
  --dart-define=WALLETCONNECT_PROJECT_ID=<your_reown_project_id>
```

Create the Reown project id at https://cloud.reown.com (do not invent one). Details: [`app/README.md`](./app/README.md).

### Hardhat / verify (optional)

Copy `.env.example` → `.env`, fill `SEPOLIA_RPC_URL` / `SEPOLIA_PRIVATE_KEY` / `ETHERSCAN_API_KEY`, then see `contracts/README.md`.

## Next

**Phase 3**: NestJS event indexer + Mongo + `IndexedContractRepository` with chain fallback.
