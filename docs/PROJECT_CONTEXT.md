# Gardenaz Contracts Context

Read this before modifying the contracts package.

## Product role

This package is the retained Gardenaz trust layer for Mantle:

- `AgentIdentity` keeps ERC-8004-style identity NFTs for AI agents
- `AutopilotPolicy` keeps deterministic user guardrails
- `DecisionLog` keeps on-chain benchmark records for AI decisions and outcomes

The contracts package no longer owns mock vault custody, mock settlement tokens, or mock route adapters.

## Current deployment artifact scope

Network: Mantle Sepolia (`5003`)

- AgentIdentity: `0x7d4cF8dAcCdc589d8601CB547d693c73dd5724e2`
- DecisionLog: `0x16E67F2Aaa40767FefeD0f2E1cF6bE87Ac3722Da`
- AutopilotPolicy: `0xd35fc1eb7BA3429f1B206FA6b054bbB71eCbD7e8`

Registered agent snapshot retained in artifact:

- agentId: `1`
- URI: `ipfs://bafkreica6vuhzakepbjntfjqhddmjh6vicpgcep2a657xfwtjkgb56kvxu`
- owner / wallet: `0x143974B30727F9856131BD6F37E64679aF5F0626`

## Hackathon invariants

The package must continue to preserve these three properties:

1. On-chain benchmarking of AI decisions and outcomes on Mantle
2. ERC-8004 agent identity NFT as the canonical identity primitive
3. Radical transparency through readable policy state, decision logs, and proof-friendly events

## Key files

- `contracts/AgentIdentity.sol`
- `contracts/AutopilotPolicy.sol`
- `contracts/DecisionLog.sol`
- `script/Deploy.s.sol`
- `script/VerifyMantleSepolia.sh`
- `deployments/mantle-sepolia.json`
- `docs/AUDIT.md`

## Verification

Run:

```bash
cd /mnt/e/web3/gardenaz/contracts
/home/zandhi/.foundry/bin/forge test -vv
```

This package should pass with only retained-contract tests.

## Current constraints

- `DecisionLog` is the benchmark anchor, not a strategy executor
- `AutopilotPolicy` is the policy proof surface, not a custody or protocol adapter layer
- `AgentIdentity` is still required because Gardenaz keeps ERC-8004 identity in the product architecture

## Do next

1. Keep ABI artifacts for the retained contracts aligned with source.
2. Expand benchmark payloads if Agni execution needs richer proof fields.
3. Preserve proof readability for app, livestream, and judging surfaces.
4. Avoid reintroducing custody or mock protocol logic into this package.
