# Gardenaz Contracts Context

Read this before modifying contracts.

## Product Role

Contracts provide the on-chain trust layer for Gardenaz:

- Agent identity / ownership / authorization.
- Policy settings and execution guardrails.
- Decision and outcome audit trail.
- Reputation and validation registry for ERC-8004-style agent ecosystem.

## Current Deployment

Network: Mantle Sepolia (`5003`)

- AgentIdentity: `0xfAc7E0Ecb4BdFB5CabDf0A4A8f9930E547771271`
- DecisionLog: `0x4f38D23639a1E8644c64b262d2E4f09d22c5aC7c`
- RiskPolicy: `0x73132c590b323B37344d52C9adaDA2dA939896d3`
- ReputationRegistry: `0xC2a58107725a773A21102f575104b869dAfFCb4d`
- ValidationRegistry: `0x25863A08185bb82C7C363745702125800b4509da`
- AutopilotPolicy: `0xe04003396491954919a851fBbF90d87555cDdFEf`

Agent ID:

- agentId: `1`
- URI: `ipfs://bafkreica6vuhzakepbjntfjqhddmjh6vicpgcep2a657xfwtjkgb56kvxu`
- owner: `0x143974B30727F9856131BD6F37E64679aF5F0626`

## Key Files

- `contracts/AgentIdentity.sol`
- `contracts/DecisionLog.sol`
- `contracts/AutopilotPolicy.sol`
- `contracts/RiskPolicy.sol`
- `contracts/ReputationRegistry.sol`
- `contracts/ValidationRegistry.sol`
- `script/Deploy.s.sol`
- `deployments/mantle-sepolia.json`
- `docs/AUDIT.md`

## Current Verification

Run:

```bash
cd /root/projects/Gardenaz/contracts
/root/.foundry/bin/forge test -vv
```

Latest audit: 17 tests pass.

## Known Gaps

- DecisionLog write/outcome functions public.
- Decision hash can be overwritten.
- Outcomes mutable forever.
- AutopilotPolicy `recordExecution` public.
- AgentIdentity `updateReputation` public.
- RiskPolicy overlaps AutopilotPolicy and does not enforce daily loss.
- Contract policy gate not strongly linked to DecisionLog logging.
- Deployment script does not write JSON/verify/register/configure.

## Do Next

1. Add auth and duplicate guards to DecisionLog.
2. Restrict AutopilotPolicy recordExecution.
3. Restrict/remove public reputation update.
4. Clarify RiskPolicy vs AutopilotPolicy.
5. Add policy proof/snapshot fields or on-chain policy check to decisions.
6. Add deployment hygiene scripts.
