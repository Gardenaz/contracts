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
: "${RISK_POLICY_ADDRESS:?Missing RISK_POLICY_ADDRESS}"
: "${REPUTATION_REGISTRY_ADDRESS:?Missing REPUTATION_REGISTRY_ADDRESS}"
: "${VALIDATION_REGISTRY_ADDRESS:?Missing VALIDATION_REGISTRY_ADDRESS}"
: "${AUTOPILOT_POLICY_ADDRESS:?Missing AUTOPILOT_POLICY_ADDRESS}"
: "${GARDEN_USD_MOCK_ADDRESS:?Missing GARDEN_USD_MOCK_ADDRESS}"
: "${GARDEN_RWA_MOCK_VAULT_ADDRESS:?Missing GARDEN_RWA_MOCK_VAULT_ADDRESS}"
: "${STEADY_ASSET_ADDRESS:?Missing STEADY_ASSET_ADDRESS}"
: "${GROWTH_ASSET_ADDRESS:?Missing GROWTH_ASSET_ADDRESS}"
: "${BOOST_ASSET_ADDRESS:?Missing BOOST_ASSET_ADDRESS}"

FORGE_BIN="${FORGE_BIN:-/home/zandhi/.foundry/bin/forge}"
CAST_BIN="${CAST_BIN:-/home/zandhi/.foundry/bin/cast}"
CHAIN_ID="${CHAIN_ID:-5003}"

verify_contract() {
  local address="$1"
  local target="$2"
  shift 2

  "$FORGE_BIN" verify-contract "$address" "$target" \
    --chain "$CHAIN_ID" \
    --rpc-url "$MANTLE_RPC_URL" \
    --etherscan-api-key "$ETHERSCAN_API_KEY" \
    "$@"
}

echo "Verifying core contracts..."
verify_contract "$AGENT_IDENTITY_ADDRESS" "contracts/AgentIdentity.sol:AgentIdentity"
verify_contract "$DECISION_LOG_ADDRESS" "contracts/DecisionLog.sol:DecisionLog"
verify_contract "$RISK_POLICY_ADDRESS" "contracts/RiskPolicy.sol:RiskPolicy"
verify_contract "$REPUTATION_REGISTRY_ADDRESS" "contracts/ReputationRegistry.sol:ReputationRegistry" \
  --constructor-args "$("$CAST_BIN" abi-encode "constructor(address)" "$AGENT_IDENTITY_ADDRESS")"
verify_contract "$VALIDATION_REGISTRY_ADDRESS" "contracts/ValidationRegistry.sol:ValidationRegistry" \
  --constructor-args "$("$CAST_BIN" abi-encode "constructor(address)" "$AGENT_IDENTITY_ADDRESS")"
verify_contract "$AUTOPILOT_POLICY_ADDRESS" "contracts/AutopilotPolicy.sol:AutopilotPolicy"

echo "Verifying settlement and route assets..."
verify_contract "$GARDEN_USD_MOCK_ADDRESS" "contracts/GardenUsdMock.sol:GardenUsdMock"
verify_contract "$STEADY_ASSET_ADDRESS" "contracts/GardenStrategyAssetMock.sol:GardenStrategyAssetMock" \
  --constructor-args "$("$CAST_BIN" abi-encode "constructor(string,string)" "Garden Strategy USDC" "gUSDC")"
verify_contract "$GROWTH_ASSET_ADDRESS" "contracts/GardenStrategyAssetMock.sol:GardenStrategyAssetMock" \
  --constructor-args "$("$CAST_BIN" abi-encode "constructor(string,string)" "Garden Strategy ETH" "gETH")"
verify_contract "$BOOST_ASSET_ADDRESS" "contracts/GardenStrategyAssetMock.sol:GardenStrategyAssetMock" \
  --constructor-args "$("$CAST_BIN" abi-encode "constructor(string,string)" "Garden Strategy mETH" "gmETH")"
verify_contract "$GARDEN_RWA_MOCK_VAULT_ADDRESS" "contracts/GardenRwaMockVault.sol:GardenRwaMockVault" \
  --constructor-args "$("$CAST_BIN" abi-encode "constructor(address)" "$GARDEN_USD_MOCK_ADDRESS")"

echo "All contracts verified."
