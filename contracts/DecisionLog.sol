// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract DecisionLog {
    struct Decision { uint256 agentId; bytes32 decisionHash; bytes32 strategyId; address targetProtocol; uint256 amount; uint8 riskLevel; uint8 outcome; uint256 timestamp; }
    mapping(uint256 => Decision) public decisions;
    uint256 public decisionCount;
    event DecisionLogged(uint256 indexed decisionId, uint256 indexed agentId, bytes32 decisionHash, uint8 riskLevel);
    event OutcomeUpdated(uint256 indexed decisionId, uint8 outcome);
    function logDecision(uint256 agentId, bytes32 decisionHash, bytes32 strategyId, address targetProtocol, uint256 amount, uint8 riskLevel) external returns (uint256) {
        uint256 id = ++decisionCount;
        decisions[id] = Decision(agentId, decisionHash, strategyId, targetProtocol, amount, riskLevel, 0, block.timestamp);
        emit DecisionLogged(id, agentId, decisionHash, riskLevel);
        return id;
    }
    function updateOutcome(uint256 decisionId, uint8 outcome) external {
        decisions[decisionId].outcome = outcome;
        emit OutcomeUpdated(decisionId, outcome);
    }
}
