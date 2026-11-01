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
- **Not started**: Phase 3 indexer, Phase 4 Explore, Sepolia production deploy (needs your secrets)

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
flutter run -d chrome
```

See [`app/README.md`](./app/README.md) for Sepolia + MetaMask (`FACTORY_ADDRESS`, `WALLETCONNECT_PROJECT_ID`).

### Optional Sepolia deploy

Copy `.env.example` → `.env`, fill `SEPOLIA_RPC_URL` / `SEPOLIA_PRIVATE_KEY` / `ETHERSCAN_API_KEY`, then see `contracts/README.md`. After deploy, set the printed factory address as `FACTORY_ADDRESS` for the app.

## Next

**Phase 3**: NestJS event indexer + Mongo + `IndexedContractRepository` with chain fallback.
