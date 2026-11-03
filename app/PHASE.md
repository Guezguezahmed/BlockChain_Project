# App — Phase 2 MVP

Implemented:

- Clean architecture: `presentation` / `domain` / `data`
- `ContractRepository` + `MockContractRepository` + `ChainContractRepository` (web3dart)
- Wallet: Reown AppKit (WalletConnect) → MetaMask, Sepolia only; mock wallet for UI
- Screens: Home, Wallet, Preset picker, Create Escrow, My Contracts, Contract detail (state-aware actions)
- Config via `--dart-define` (`FACTORY_ADDRESS`, `SEPOLIA_RPC_URL`, `WALLETCONNECT_PROJECT_ID`, `USE_MOCK`)
- Live Sepolia Factory default: `0x0E847b5Dccd09e73199e3689fC4D0D25A0133F08` (Escrow impl `0x4bb80444D6669588F7bf1ed6b0EFE71B7Aacf25E`)
- Chain mode: `USE_MOCK=false` + `WALLETCONNECT_PROJECT_ID` from https://cloud.reown.com

Not in this phase: backend indexer / `IndexedContractRepository` (Phase 3), Explore page (Phase 4).
