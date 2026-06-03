# Gardenaz Contracts Audit

Last updated: 2026-06-03

## Scope

Repo: `/root/projects/Gardenaz/contracts`

Purpose: Solidity contracts for Gardenaz agent identity, policy gating, decision/outcome logging, reputation, and validation.

## Current Status

Working:

- Foundry tests pass: 17/17.
- Mantle Sepolia deployment artifacts exist.
- Agent ID 1 is registered with IPFS metadata.
- Deployment JSON is copied into app and agent repos.

Current deployment:

- Network: Mantle Sepolia
- Chain ID: `5003`
- AgentIdentity: `0xfAc7E0Ecb4BdFB5CabDf0A4A8f9930E547771271`
- DecisionLog: `0x4f38D23639a1E8644c64b262d2E4f09d22c5aC7c`
- RiskPolicy: `0x73132c590b323B37344d52C9adaDA2dA939896d3`
- ReputationRegistry: `0xC2a58107725a773A21102f575104b869dAfFCb4d`
- ValidationRegistry: `0x25863A08185bb82C7C363745702125800b4509da`
- AutopilotPolicy: `0xe04003396491954919a851fBbF90d87555cDdFEf`

Registered agent:

- agentId: `1`
- URI: `ipfs://bafkreica6vuhzakepbjntfjqhddmjh6vicpgcep2a657xfwtjkgb56kvxu`
- owner/wallet: `0x143974B30727F9856131BD6F37E64679aF5F0626`

Not production-ready:

- Several write functions are public.
- Policy gate is not strongly linked to DecisionLog.
- Duplicate policy contracts need clarification.
- Explorer verification status missing.

## Findings

### P0: DecisionLog write paths are public

- File: `contracts/DecisionLog.sol`
- Functions:
  - `logDecision`
  - `updateOutcome`
  - `recordOutcome`
  - `recordOutcomeForHash`
- Anyone can log fake decisions or overwrite outcomes.

Fix:

- Add authorization:
  - agent owner or authorized wallet via `AgentIdentity.isAuthorizedOrOwner`, or
  - dedicated relayer role, or
  - Ownable/AccessControl role.

### P0: Decision hash can be overwritten

- File: `contracts/DecisionLog.sol`
- `decisionIdsByHash[decisionHash] = id` overwrites previous mapping.

Fix:

- Require non-zero `decisionHash`.
- Require `decisionIdsByHash[decisionHash] == 0`.

### P0: Outcomes mutable forever

- File: `contracts/DecisionLog.sol`
- Outcome update functions can repeatedly replace outcome data.

Fix options:

1. Make outcome one-shot immutable.
2. Store versioned outcome updates.
3. Restrict updates to authorized relayer/agent.

### P0: AutopilotPolicy recordExecution is public

- File: `contracts/AutopilotPolicy.sol`
- `recordExecution()` can be called by anyone.
- Attack: grief user by consuming daily loss and updating last execution time.

Fix:

- Restrict caller to user, authorized agent, or relayer role.

### P0: AgentIdentity reputation update is public

- File: `contracts/AgentIdentity.sol`
- `updateReputation()` can be called by anyone.

Fix:

- Remove function or restrict it to `ReputationRegistry`/owner/admin.

### P1: DecisionLog not linked to policy gate

- File: `contracts/DecisionLog.sol`
- `logDecision()` does not check `AutopilotPolicy.canExecute()`.

Fix options:

1. Add policy fields to `logDecision` and verify on-chain.
2. Store `policySnapshotHash`, `policyAllowed`, policy contract address, and off-chain proof.
3. Let agent relayer verify policy before logging, but document trust model clearly.

### P1: AutopilotPolicy daily loss check incomplete

- File: `contracts/AutopilotPolicy.sol`
- `canExecute()` checks current stored daily loss, not prospective new loss.

Fix:

- Add expected/prospective loss input or enforce loss in execution recording path.

### P1: Policy allowlist stale entries

- File: `contracts/AutopilotPolicy.sol`
- `setAutopilotPolicy()` adds allowed protocols but does not clear old ones.

Fix:

- Add explicit remove/reset function or enumerable per-user allowlist.

### P1: RiskPolicy duplicates AutopilotPolicy

- File: `contracts/RiskPolicy.sol`
- Stores max daily loss but does not enforce it.
- Overlaps with `AutopilotPolicy`.

Fix:

- Merge/deprecate/clarify contract roles.
- If kept, enforce max daily loss and risk bounds.

### P1: AgentIdentity owner field can go stale

- File: `contracts/AgentIdentity.sol`
- Struct stores owner, but ERC721 transfers change `ownerOf(agentId)`.

Fix:

- Remove stored owner from struct or update it on transfer hooks.

### P1: active flag not enforced by registries

- Files:
  - `contracts/AgentIdentity.sol`
  - `contracts/ReputationRegistry.sol`
  - `contracts/ValidationRegistry.sol`
- `active` can be changed but registries only check owner/existence.

Fix:

- Add `isActive(agentId)` checks where needed.

### P1: Validation and feedback spam possible

- Files:
  - `contracts/ValidationRegistry.sol`
  - `contracts/ReputationRegistry.sol`
- Public request/feedback paths may be intended but can be spammed.

Fix:

- Define trust model: public, fee-gated, allowlisted, or signed-feedback only.

### P2: Deployment script minimal

- File: `script/Deploy.s.sol`
- Deploys and prints addresses only.
- Does not write JSON, verify contracts, register agent, or configure policy.

Fix:

- Add post-deploy scripts or document exact manual steps.

### P2: ERC-8004 status needs precision

Current implementation is ERC-8004-style identity/reputation/validation, but may not expose formal ERC-8004 interface support.

Fix:

- Compare hackathon/spec interface expectations.
- Add interface IDs/support if required.

## Integration Notes

Deployment JSON exists in:

- `contracts/deployments/mantle-sepolia.json`
- `app/src/lib/contracts/mantle-sepolia.json`
- `agent/src/config/mantle-sepolia.json`

Agent relayer supports DecisionLog calls, but latest audit did not confirm live path reads `AutopilotPolicy.canExecute()` before logging.

App has contract JSON but does not yet show live proof/contract state in UI.

## Verification Snapshot

- `/root/.foundry/bin/forge test -vv` passes: 17 tests.

## Next Contracts Work Order

1. Add authorization to DecisionLog write/outcome functions.
2. Add duplicate hash guard and outcome immutability/versioning.
3. Restrict `AutopilotPolicy.recordExecution`.
4. Restrict/remove `AgentIdentity.updateReputation`.
5. Clarify/merge RiskPolicy vs AutopilotPolicy.
6. Add policy linkage to DecisionLog/relayer.
7. Add deployment/post-deploy/verification scripts and docs.
