# PROJECT BRIEF FOR AI ASSISTANTS (Cursor)

> Read this entire file before writing or changing any code.
> This is the single source of truth for what we are building, why, and the rules we follow.
> If a request conflicts with this file, say so and ask before proceeding.

Project name: **[PROJECT_NAME]** (placeholder, rename later)
Team: **one developer** (full stack: contracts, backend, app). Prefer simple, readable, well-tested code over clever code.

---

## 1. What we are building

A **decentralized, no-code smart contract builder**.

A user opens the app, picks a **preset** (a ready-made contract template such as Escrow or Rental), fills in a simple form (parties, amount, dates), and taps **Deploy**. The app creates a real smart contract on the Ethereum **Sepolia testnet** for them, without them writing any code. Afterwards they can view, fund, release, or refund the contract from the app, and everything is publicly verifiable on the blockchain.

### Why it exists (academic context)
This is a university project. The assignment: *build a distributed blockchain app that no one owns, used to create virtual (smart) contracts.*
The product story: the developer runs a SaaS startup (e.g. tools and websites for car rental agencies). Rental agreements are one of the presets. The builder itself is a general tool.

### The core promise: "No one owns it"
This is the main grading criterion. Every design decision must protect it:

- Smart contracts have **no owner, no admin, no pause, no upgrade mechanism, no fee recipient**. Nobody (including the developer) can change rules, freeze, or take funds.
- The **blockchain is the source of truth.** If the app and backend are deleted, all contracts keep working and funds stay safe. Users can still interact through a block explorer (Etherscan) because contracts are verified.
- The **backend is optional**, only a rebuildable cache for speed. The app must still work (slower) with the backend offline.
- Users **sign their own transactions** with their own wallet. The backend never holds keys, never signs, never sends transactions.
- All transactions and contracts are **public and visible** by design (transparency is a feature). The app shows everything, including an Explore page of all contracts.

---

## 2. Presets (templates)

A **preset** is a pre-written, tested Solidity template with parameters. Users never write code; they fill a form that maps to the template's parameters. The factory contract creates a new instance of the template for each user.

| Preset | Status | Summary |
|---|---|---|
| **Escrow** | v1, build first | Buyer locks ETH, releases it to seller when satisfied, or gets refunded. |
| **Rental** | v2 | Renter pays fee + deposit; deposit returned on return; penalty on lateness. |
| **Milestone payment** | v3 | Client funds a project; freelancer is paid per approved milestone. |
| **Time-lock** | v4 (optional) | Funds release to a beneficiary after a date. |

### Escrow preset (v1 spec, defined in `contracts/interfaces/IContracts.sol`)

- Buyer creates the escrow via the factory with `(seller, amount, deadline)`. Caller becomes the buyer.
- States: `Created -> Funded -> Released | Refunded` (final states are terminal).
- `fund()` payable, buyer only, must send exactly `amount`. `Created -> Funded`.
- `release()`, buyer only, pays seller. `Funded -> Released`.
- `refundBySeller()`, seller only, any time while funded. `Funded -> Refunded`.
- `refundAfterDeadline()`, buyer only, only after `deadline`. `Funded -> Refunded`.
- Every state change emits an event: `Funded`, `Released`, `Refunded`.
- **ETH only.** No ERC20 in v1. No arbiter/dispute in v1. No fee.
- Known limitation (document in write-up): after the deadline the buyer can always reclaim, so the seller carries some risk.

### Adding a new preset (checklist, follow in order)
1. Add its interface + events + states to `contracts/interfaces/IContracts.sol` and a new value to `TemplateType` (append only, never reorder existing enum values).
2. Implement the template contract using the clone-initializer pattern.
3. Add a `createXxx(...)` function to the factory (emit `ContractCreated`).
4. Write full tests (see section 6).
5. Add the form + detail screen in Flutter behind the existing repository interface.
6. Add event handling in the indexer.
7. Update this file's preset table.

---

## 3. Architecture

```
 Flutter app  --(web3dart, user's wallet signs)-->  Sepolia contracts (source of truth)
     |                                                   ^
     | REST (read-only, optional)                        | events (viem)
     v                                                   |
 NestJS + MongoDB (cache/indexer, rebuildable) ----------+
```

- **Contracts**: Solidity ^0.8.24, Hardhat, OpenZeppelin, Sepolia.
- **App**: Flutter (Dart), `web3dart` for chain reads/writes, wallet connection via **Reown AppKit (WalletConnect)** to MetaMask. (Open decision: mobile vs web target. Default assumption: support Reown AppKit so the same wallet code works on both. For Flutter Web only, an injected MetaMask provider is also acceptable.)
- **Backend**: NestJS (TypeScript) + MongoDB + **viem** to listen to events. Read-only REST API.
- **Hardhat tests and deploy scripts**: TypeScript with **ethers.js**.
- Network: **Sepolia only.** Never reference or deploy to mainnet.

### Repo layout (monorepo)
```
/contracts      Hardhat project (Solidity, tests, deploy scripts)
  /contracts
    /interfaces   IContracts.sol  <-- shared interface, source of truth
    ContractFactory.sol
    templates/Escrow.sol
  /test
  /scripts or /ignition
/backend        NestJS indexer + REST API
/app            Flutter app
/docs           write-up, diagrams
AGENTS.md       this file
```

### Single source of truth for the interface
`contracts/interfaces/IContracts.sol` defines functions, events, states, and enums. The Flutter app and the backend are written against it. **If a contract signature or event changes, update this file first, then regenerate/update ABIs in `app/` and `backend/`.** Never let ABIs drift.

---

## 4. Smart contract rules (strict)

**Must do**
- Solidity `^0.8.24`, SPDX license header, NatSpec comments on every external function.
- Use OpenZeppelin `Clones` (EIP-1167) in the factory. Templates use an `initialize(...)` function guarded so it can only run once (custom `initialized` flag or OZ `Initializable`), called by the factory in the same transaction as creation.
- Use OpenZeppelin `ReentrancyGuard` on any function that sends ETH.
- Follow **checks-effects-interactions**: validate, update state, then transfer.
- Send ETH with `call{value: ...}("")` and revert on failure. No `transfer`/`send`.
- Use **custom errors** (`error NotBuyer();`) instead of revert strings.
- Validate inputs: non-zero addresses, seller != buyer, `amount > 0`, `deadline > block.timestamp`.
- Emit an event for every state change and every contract creation (with `timestamp`).
- Factory keeps a public registry: `getAllContracts()`, `getContractsByUser(address)`, `totalContracts()`.
- Make state-changing functions enforce the state machine (e.g. `fund()` only in `Created`).

**Must never do**
- No `Ownable`, `AccessControl`, `Pausable`, or any privileged role.
- No upgradeable proxies (UUPS/Transparent/Beacon). Minimal-proxy clones are fine because the logic is immutable.
- No `selfdestruct`, no `delegatecall` to arbitrary addresses, no hidden fee or wallet that receives value.
- No `tx.origin` for auth. No on-chain randomness assumptions. No loops over unbounded arrays inside state-changing functions.
- **No personal data on-chain** (names, phone numbers, IDs, addresses). Only wallet addresses, amounts, dates, and conditions. For documents, store only a hash.

---

## 5. App rules (Flutter)

- Clean separation: `presentation` (screens/widgets), `domain` (models, repository interfaces), `data` (implementations).
- All data access goes through a **`ContractRepository` interface** with three implementations:
  1. `MockContractRepository`: fake data, for UI development before the chain is ready.
  2. `ChainContractRepository`: reads/writes directly via `web3dart`. This is the **fallback and the source of truth**.
  3. `IndexedContractRepository`: uses the backend REST API for fast lists, and falls back to `ChainContractRepository` if the backend is unreachable.
- Screens never call web3dart or HTTP directly, only repositories.
- State management: Riverpod (or Bloc if already chosen), consistent across the app.
- Screens: Home, Preset picker, per-preset create form, My Contracts, Contract detail (with state-aware action buttons), Explore (all public contracts), Wallet connect.
- Action buttons depend on contract `state` and the connected wallet's role (e.g. "Deposit" only for buyer in `Created`).
- Validate forms: valid addresses (EIP-55 checksum), positive amounts, future dates. Show ETH amounts to users (convert from wei), never raw wei.
- **Before any money-moving action**, re-read the contract's real state from the chain, never trust the cached backend copy.
- Always show: contract address, network (Sepolia), link to Etherscan, transaction hash with status (pending/confirmed/failed), and a clear notice that contracts are public.
- Handle wallet errors gracefully: not installed, wrong network (prompt to switch to Sepolia), user rejected, insufficient funds.
- Never store private keys or seed phrases. The wallet app handles signing.

---

## 6. Backend rules (NestJS + Mongo, optional layer)

Purpose: speed only. It indexes events so the app can list, search, and filter quickly.

- Uses **viem** to listen to the factory's `ContractCreated` and each template's events.
- MongoDB collections (suggested):
  - `contracts`: `address`, `creator`, `templateType`, `createdAt`, `participants[]`, `lastKnownState`, `blockNumber`
  - `events`: `contractAddress`, `eventName`, `args`, `txHash`, `blockNumber`, `logIndex`, `timestamp` (unique index on `txHash + logIndex`)
  - `syncState`: `lastProcessedBlock`
- Endpoints (read-only):
  - `GET /contracts` (pagination, filters by `type`, `state`)
  - `GET /contracts?user=0x...`
  - `GET /contracts/:address`
  - `GET /contracts/:address/events`
  - `GET /health`
- **Must be rebuildable**: provide `npm run resync -- --from <block>` that wipes the DB and replays all events from the chain. Indexing must be **idempotent** (re-processing an event never duplicates data).
- Handle reorgs sensibly (small confirmation delay, e.g. wait a few blocks before marking final).
- **Never** hold private keys, sign or send transactions, or store anything that exists only in Mongo.
- Config via environment variables: `RPC_URL`, `FACTORY_ADDRESS`, `START_BLOCK`, `MONGO_URI`. Never commit secrets.

---

## 7. Testing and quality

**Contracts (Hardhat + ethers.js), required for every template**
- Happy path for every state transition.
- Every revert path (wrong caller, wrong state, wrong amount, early/late deadline, double action).
- Events emitted with correct arguments.
- Funds accounting: contract balance and recipient balances after each action.
- Reentrancy attempt test (malicious receiver contract).
- Factory: clone creation, registry contents, `getContractsByUser`, event emission.
- Aim for high coverage (`npx hardhat coverage`).
- Verify all deployed contracts on Etherscan (`hardhat-verify`).

**App**: widget tests for forms and state-dependent buttons, unit tests for repositories using the mock.
**Backend**: unit tests for event handlers, and a test proving a re-sync reproduces identical data.

---

## 8. Roadmap

1. **Phase 0, setup**: monorepo, Hardhat project, Flutter project, NestJS project, `IContracts.sol` committed.
2. **Phase 1, Escrow contract**: implement Escrow + Factory, full tests, deploy to Sepolia, verify on Etherscan.
3. **Phase 2, app MVP**: wallet connect, Escrow create form, My Contracts, detail screen with actions, using `ChainContractRepository` against Sepolia.
4. **Phase 3, backend indexer**: event listener, Mongo, REST API, resync script, `IndexedContractRepository` with fallback.
5. **Phase 4, Explore page** and polish (transaction status UI, error handling, Etherscan links).
6. **Phase 5, more presets**: Rental, then Milestone, following the "adding a new preset" checklist.
7. **Phase 6, decentralized hosting + write-up**: Flutter Web build on IPFS (if web), open-source repo, documentation of the "no one owns it" design, limitations, and future work (ERC20 support, arbiter/dispute resolution, The Graph subgraph, privacy via zero-knowledge proofs).

---

## 9. How the AI assistant should work with me

- I am a **beginner in blockchain**. Explain the *why* briefly when you introduce a new concept (e.g. clones, reentrancy), but keep code comments concise.
- Work in **small steps**. Do one phase or one feature at a time, then stop so I can test.
- Before big changes, state the plan in a few lines. Don't refactor unrelated code.
- Prefer boring, standard patterns and well-known libraries over novel ones.
- Do not add dependencies without saying why.
- If something is ambiguous or conflicts with the "no one owns it" rules, **ask**, don't guess.
- Never invent contract addresses, ABIs, or API behaviors. Use values from the repo or ask me.
- When you finish a task, tell me: what changed, how to run/test it, and what's next.

## 10. Quick glossary

- **Smart contract**: a program on the blockchain that enforces an agreement automatically.
- **Preset**: our name for a ready-made contract template users configure via a form.
- **Factory**: a contract that creates new instances of a template and keeps a public registry.
- **Clone (EIP-1167)**: a cheap copy of a template contract; each user's contract is a clone.
- **Sepolia**: Ethereum test network with free fake ETH.
- **Wei**: the smallest ETH unit (1 ETH = 10^18 wei).
- **ABI**: the description of a contract's functions and events, used by the app and backend to talk to it.
- **Indexer**: a service that reads blockchain events and stores them for fast queries.
