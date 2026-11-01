# BlockChain_Project

Decentralized, no-code smart contract builder (university project). Users configure presets (starting with **Escrow**) and deploy real contracts on **Ethereum Sepolia**. No owner, no admin, no fees — the chain is the source of truth.

Full rules and roadmap: [`AGENTS.md`](./AGENTS.md).

## Monorepo layout

| Path | Role |
|---|---|
| `contracts/` | Hardhat (Solidity ^0.8.24, ethers.js, OpenZeppelin) |
| `backend/` | NestJS indexer + read-only REST (scaffold only in Phase 0/1) |
| `app/` | Flutter client (scaffold only in Phase 0/1) |
| `docs/` | Write-up / diagrams |
| `AGENTS.md` | Project brief (source of truth for assistants) |

## Phase 0 + Phase 1 (current)

- Shared interface: `contracts/contracts/interfaces/IContracts.sol`
- Implemented: `Escrow` template + `ContractFactory` (EIP-1167 clones)
- Full Hardhat tests
- Empty Flutter + NestJS scaffolds
- **Not started:** Phase 2 app features, Phase 3 indexer, Sepolia production deploy

### Run contract tests

```bash
cd contracts
npm install
npm test
```

### Optional Sepolia deploy

Copy `.env.example` → `.env`, fill `SEPOLIA_RPC_URL` / `SEPOLIA_PRIVATE_KEY` / `ETHERSCAN_API_KEY`, then see `contracts/README.md`.

## Next

**Phase 2** (after approval): Flutter MVP — wallet connect, Escrow create form, My Contracts, detail actions via `ChainContractRepository` against Sepolia.
