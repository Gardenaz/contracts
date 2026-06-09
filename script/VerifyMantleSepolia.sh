#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source ./.env
  set +a
fi

if [ -f ../agent/.env ]; then
  set -a
  # shellcheck disable=SC1091
  source ../agent/.env
  set +a
fi

: "${MANTLE_RPC_URL:?Missing MANTLE_RPC_URL}"
: "${ETHERSCAN_API_KEY:?Missing ETHERSCAN_API_KEY}"
: "${AGENT_IDENTITY_ADDRESS:?Missing AGENT_IDENTITY_ADDRESS}"
: "${DECISION_LOG_ADDRESS:?Missing DECISION_LOG_ADDRESS}"
: "${AUTOPILOT_POLICY_ADDRESS:?Missing AUTOPILOT_POLICY_ADDRESS}"

FORGE_BIN="${FORGE_BIN:-/home/zandhi/.foundry/bin/forge}"
CHAIN_ID="${CHAIN_ID:-5003}"

verify_contract() {
  local address="$1"
  local target="$2"

  "$FORGE_BIN" verify-contract "$address" "$target" \
    --chain "$CHAIN_ID" \
    --rpc-url "$MANTLE_RPC_URL" \
    --etherscan-api-key "$ETHERSCAN_API_KEY"
}

echo "Verifying retained Gardenaz trust-layer contracts..."
verify_contract "$AGENT_IDENTITY_ADDRESS" "contracts/AgentIdentity.sol:AgentIdentity"
verify_contract "$DECISION_LOG_ADDRESS" "contracts/DecisionLog.sol:DecisionLog"
verify_contract "$AUTOPILOT_POLICY_ADDRESS" "contracts/AutopilotPolicy.sol:AutopilotPolicy"

echo "Verification requests submitted."
