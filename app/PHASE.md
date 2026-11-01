# App — Phase 2 MVP

Implemented:

- Clean architecture: `presentation` / `domain` / `data`
- `ContractRepository` + `MockContractRepository` + `ChainContractRepository` (web3dart)
- Wallet: Reown AppKit (WalletConnect) → MetaMask, Sepolia only; mock wallet for UI
- Screens: Home, Wallet, Preset picker, Create Escrow, My Contracts, Contract detail (state-aware actions)
- Config via `--dart-define` (`FACTORY_ADDRESS`, `SEPOLIA_RPC_URL`, `WALLETCONNECT_PROJECT_ID`, `USE_MOCK`)

Not in this phase: backend indexer / `IndexedContractRepository` (Phase 3), Explore page (Phase 4).
