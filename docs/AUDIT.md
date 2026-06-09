# Gardenaz Contracts Audit

Last updated: 2026-06-06

## Scope

Repo path: `E:/web3/gardenaz/contracts`

Purpose: retained Mantle trust layer for Gardenaz AI benchmarking, ERC-8004-style agent identity, policy proof, and radical transparency.

## Current architecture

Retained contracts:

- `AgentIdentity`
- `DecisionLog`
- `AutopilotPolicy`

Removed from this code cut:

- mock settlement token
- mock vault
- mock adapters
- duplicate risk contract
- reputation and validation registries from the old hackathon-era mock architecture

## Hackathon invariants preserved

### On-chain benchmarking on Mantle

`DecisionLog` remains the source of truth for AI decision and outcome records. This preserves the benchmark trail needed to compare agent behavior publicly.

### ERC-8004 agent identity NFT

`AgentIdentity` remains the identity anchor for every participating AI agent. This preserves an on-chain record of agent provenance and achievement.

### Radical transparency

The retained trust layer is intentionally proof-friendly:

- `AutopilotPolicy` exposes user-approved guardrails
- `DecisionLog` exposes decision and outcome records
- `AgentIdentity` exposes public identity metadata

These three surfaces are the on-chain foundation for live proof, live streaming, and judge inspection.

## Verification snapshot

Required verification command:

```bash
cd /mnt/e/web3/gardenaz/contracts
/home/zandhi/.foundry/bin/forge test -vv
```

Task 1 is only complete when tests pass without any imports from deleted contracts.

## Open findings

### P1: DecisionLog benchmark payload is still generic

- File: `contracts/DecisionLog.sol`

The benchmark payload is adequate for current proof anchoring, but future direct Agni execution will likely need richer fields such as token pair, route type, fee tier, minimum output, or LP position identifiers.

Impact:

- current benchmark trail is valid but coarse
- later DeFi execution proof may be harder to interpret without expansion

### P1: AgentIdentity reputation is centrally administered

- File: `contracts/AgentIdentity.sol`

`updateReputation()` is now restricted to the contract owner, which is the smallest coherent retained-control model after removing the old registry stack.

Impact:

- prevents arbitrary third parties from mutating reputation
- still leaves a centralized admin trust assumption until a dedicated reputation flow is designed

### P1: AutopilotPolicy caller model is still minimal

- File: `contracts/AutopilotPolicy.sol`

The contract now uses an `authorized caller` gate for execution recording, which is directionally correct for direct executor flows. The remaining open question is whether the final Agni executor model should use a single relayer, a set of approved callers, or richer role separation.

## Notes for follow-up

1. If Agni execution is logged directly, decide whether `authorized callers` should become a dedicated relayer/executor role model.
2. If live proof needs richer semantics, extend `DecisionLog` rather than reintroducing mock route contracts.
3. Preserve the three hackathon invariants in every future contract change.
4. If decentralized reputation returns later, replace the owner-only path with a narrowly scoped benchmark/reputation writer model.
