# AgentGate

A members-only daily check-in dApp for **Binance Agent ID** holders on BNB Chain,
built for the Binance Agent ID Hackathon.

Only wallets that hold an Agent ID can get in. Members check in once a day to
build a streak, and after 3 lifetime check-ins they can claim a soulbound badge
NFT that proves their participation. No funds are ever involved — AgentGate is
purely an identity gate plus a lightweight loyalty record.

## How Agent ID is used (core flow)

Agent ID is not decoration here; it is the access-control primitive of the
whole product:

1. **Gate check on every interaction.** `AgentGate.checkIn()` first calls
   `balanceOf(caller)` on the official Agent ID registry
   (`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`, SPACE ID, ERC-721 soulbound).
   If the result is 0, the call reverts — there is no other way in, no
   allowlist, no signature, no admin override.
2. **Daily check-in.** A holder may check in once per UTC day
   (`block.timestamp / 86400`). The contract records lifetime total, current
   streak (consecutive days; a skipped day resets it to 1), and the first
   check-in registers the address as a member and increments the public
   `uniqueMembers` counter exactly once.
3. **Live re-verification.** The check is performed at call time against the
   registry, so an address that no longer holds an Agent ID immediately loses
   the ability to check in.
4. **Soulbound badge.** At 3 lifetime check-ins a member can call
   `claimBadge()`. The gate instructs the badge contract to mint one
   `AgentGate Badge` (AGB) NFT to the member. The badge is non-transferable —
   it is bound to the identity that earned it, mirroring the soulbound nature
   of Agent ID itself. One badge per address, ever.

## Contracts

| Contract | File | Purpose |
|---|---|---|
| `AgentGate` | `contracts/AgentGate.sol` | Core gate: Agent ID check, daily check-ins, streaks, membership counter, badge claims. |
| `AgentBadge` | `contracts/AgentBadge.sol` | Soulbound ERC-721 badge ("AgentGate Badge", `AGB`). Minting restricted to the AgentGate contract. |
| `MockAgentId` | `contracts/mocks/MockAgentId.sol` | Test-only stand-in for the registry. **Not for production.** |

Deployment wiring (for reference; nothing is deployed yet):

1. Deploy `AgentGate(registry = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F)`.
2. Deploy `AgentBadge()`.
3. `AgentBadge.setMinter(agentGateAddress)` — owner, once.
4. `AgentGate.setBadge(agentBadgeAddress)` — owner, once.

## Owner permissions (disclosed)

The owner is the deployer. The owner's powers are deliberately minimal:

- `AgentGate.setBadge(address)` — one-time wiring of the badge contract.
  Callable exactly once; cannot be changed afterwards.
- `AgentBadge.setMinter(address)` — one-time wiring of the minter.
  Callable exactly once; cannot be changed afterwards.

**The owner has NO power over user records.** There is no function — for the
owner or anyone else — that can create, edit, or delete a member's check-in
stats, streak, membership, or badge-claim status, and no function that can
mint a badge except a member's own `claimBadge()` call. There are no admin
setters for thresholds, no pause, and no upgrade mechanism.

## Safety notes

- **No user funds, ever.** Neither contract has any payable function, and
  neither can receive, hold, transfer, or approve BNB or any token. Users only
  pay their own gas for their own transactions.
- **No approvals requested.** Using AgentGate never asks a user to approve
  token spending.
- **Users confirm their own transactions.** Every state change
  (`checkIn`, `claimBadge`) is a transaction the user signs and confirms in
  their own wallet. Nothing is executed on a user's behalf.
- **No promises.** AgentGate makes no promise of returns, rewards, or income.
  The badge is a proof-of-participation collectible.
- **Public data only.** The only identity read is the public
  `balanceOf` of the caller's own address on the Agent ID registry. AgentGate
  is not a tool for looking up other people's wallets.
- The badge uses `_mint` rather than `_safeMint` so that a member claiming
  from a smart-contract wallet can never be locked out of a badge they earned
  by a missing receiver hook.

## Run the tests

Requirements: [Foundry](https://getfoundry.sh) (`forge` 1.9.x), Solidity
0.8.24, OpenZeppelin Contracts v5.1.0 (vendored under `lib/`).

```bash
forge test
```

Expected: 16 tests, all passing — covering the Agent ID gate, same-day and
next-day rules, streak reset, unique-member counting, the badge threshold,
soulbound transfers, minter restriction, one-time wiring, loss of Agent ID,
and the explicit-owner guarantee (the contracts are deployed through a
CREATE2 factory, so ownership comes from a constructor argument, never
from the deploying address).

Dependencies are fetched with Foundry:

```bash
forge install OpenZeppelin/openzeppelin-contracts@v5.1.0
forge install foundry-rs/forge-std
```

## Deployments (BNB Chain mainnet)

Deployed 2026-11-18 through the Safe SingletonFactory (CREATE2) from the
project owner's Binance Agentic Wallet — the wallet could not create
contracts directly, and the explicit-owner constructors above are what
keep ownership with the owner rather than the factory.

| Contract | Address |
| --- | --- |
| AgentGate | `0x0Acc263D5EC9A457c1FE3d3ED690E4E084021803` |
| AgentBadge | `0x7F01B066E21157B8C9D4E8ED12a61AE9cE3F9BCa` |
| Agent ID registry (SPACE ID) | `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` |

- AgentBadge deploy tx: `0xd17f1ee93465aa37dd50fb4fbb2fb8249e205733ad7b6bd37ad797ab13bc5042`
- AgentGate deploy tx: `0x0f8a28aac0baf3a9a68de78a49ba7ce3c661caafd3c897b73816c5f1a047526c`
- Wiring: setBadge `0x9cd1d44f963a1febc2466c07910e92b24019ce73e1d8720215ddc28b8f0209a2`, setMinter `0xec2e05024419ba217377ad05deb06327f5f1f4e83021ab80a7ef8183640df67a`
- First check-in (member #1, the owner): `0xcd62c73d57813260cd17e877914ce45a5f9e22dc257da85b0555195126488dee`

Front-end: `docs/` in this repo (GitHub Pages) — a single dependency-free
page; the same files live in `web/`.

> Note for this VM: `/tmp` is a small tmpfs; if `foundryup` fails with
> "No space left on device", set `TMPDIR` to a directory on the home
> filesystem first (see BUILD_REPORT.md).
