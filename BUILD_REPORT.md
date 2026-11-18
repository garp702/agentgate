# AgentGate — Build Report (2026-11-18)

Local build only. **Nothing was deployed, no wallet was used, no external
transaction was sent.** The only external network call was a read-only
`eth_call` against a public BSC RPC (see "Production registry check").

## Toolchain

- **Foundry** forge/cast 1.9.0 (commit 6056c5845d) — installed via foundryup.
  - First install attempt failed: foundryup extracts into `/tmp`, which is a
    512 MB tmpfs on this VM ("No space left on device"). Fixed by re-running
    with `TMPDIR=$HOME/tmp-foundry`. Hardhat fallback was therefore not
    needed.
- **Solidity** 0.8.24 (pinned in `foundry.toml`), optimizer on, 200 runs.
- **OpenZeppelin Contracts v5.1.0** (`lib/openzeppelin-contracts`, tag
  v5.1.0@69c8def) and **forge-std v1.17.0**, installed via `forge install`.
- Layout note: sources live in `contracts/` (per deliverable spec), configured
  via `src = "contracts"` in `foundry.toml`; tests in `test/`.

## Test command and results

```bash
cd ~/workspace/agentgate
export PATH="$HOME/.foundry/bin:$PATH"
forge test
```

Result (final run, and re-verified after all files were in place):
**15 passed, 0 failed, 0 skipped.**

| # | Test | Covers |
|---|---|---|
| 1 | test_NonHolderCheckInReverts | checkIn without Agent ID reverts |
| 2 | test_HolderCheckInSucceedsAndStatsUpdate | holder check-in, event, stats, membership, counter |
| 3 | test_SecondCheckInSameDayReverts | one check-in per UTC day |
| 4 | test_NextDayCheckInIncrementsStreak | consecutive day → streak 2 |
| 5 | test_SkippedDayResetsStreakToOne | gap day → streak resets to 1, total keeps counting |
| 6 | test_UniqueMembersCountsEachAddressOnce | counter increments once per address |
| 7 | test_LosingAgentIdBlocksCheckIn | after mock revoke, checkIn reverts again |
| 8 | test_BadgeThresholdIsThree | badgeThreshold() == 3 |
| 9 | test_BadgeClaimByNonMemberReverts | claim without membership reverts |
| 10 | test_BadgeClaimBeforeThresholdReverts | claim at total 2 reverts |
| 11 | test_BadgeClaimAtThresholdMintsExactlyOne | claim at total 3 mints 1; second claim reverts |
| 12 | test_BadgeTransferRevertsSoulbound | transferFrom and safeTransferFrom revert |
| 13 | test_DirectBadgeMintByNonMinterReverts | only AgentGate can mint |
| 14 | test_MinterAndBadgeCanOnlyBeSetOnce | one-time wiring enforced on both contracts |
| 15 | test_BadgeMetadata | name "AgentGate Badge", symbol "AGB" |

All 10 required scenarios from the task are covered (tests 1–7, 10–12).

## Contract sizes (runtime bytecode, `forge build --sizes`)

| Contract | Runtime size | vs 24,576 B limit |
|---|---|---|
| AgentGate | 2,092 B | fine |
| AgentBadge | 4,438 B | fine |
| MockAgentId | 520 B | test only |

Build emits two lint warnings, both intentional and documented in code:
`_mint` instead of `_safeMint` in AgentBadge (prevents receiver-hook lockout
for contract-wallet claimants), and an event emitted after the external mint
call in `claimBadge` (state is updated before the call — checks-effects-
interactions is respected).

## Production registry check (read-only)

Verified the gate's exact production call against BNB Chain mainnet:

```
cast call 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F "balanceOf(address)(uint256)" \
  0xF43F767E85a8560E3CC3197d8Ba7d3A02b33B06A --rpc-url https://bsc-dataseed.binance.org
→ 1
```

The production registry answers the `balanceOf` selector as expected, and the
reference address holds 1 Agent ID — i.e. `hasAgentId` would return true for
it in production.

## Left undone (by design / awaiting decisions)

- **No deployment.** Deploying spends BNB gas and needs ipot's explicit
  go-ahead with cost figures (per INTAKE.md). Deployment order and wiring
  steps are documented in README.md.
- **No frontend / website yet.** The hackathon submission needs a project
  website; the dApp UI (connect wallet → check-in button → badge claim) is
  the next build step after contracts.
- **No BscScan verification** (follows deployment).
- **No GitHub publication yet** (open-sourcing is a hackathon requirement;
  the local repo in this directory is ready to push when approved).
- The ≥30 interacting Agent ID addresses requirement is a community/
  distribution task, not a contract task — untouched by this build.
