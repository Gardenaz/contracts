// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract DecisionLog {
    struct Decision {
        uint256 agentId;
        bytes32 decisionHash;
        bytes32 strategyId;
        address targetProtocol;
        uint256 amount;
        uint8 riskLevel;
        uint8 outcome;
        uint256 timestamp;
    }

    struct Outcome {
        bytes32 executionTxHash;
        int256 pnlBps;
        uint256 realizedApyBps;
        uint256 inputAmount;
        uint256 outputAmount;
        bool success;
        string metadataURI;
        uint256 timestamp;
    }

    mapping(uint256 => Decision) public decisions;
    mapping(uint256 => Outcome) public outcomes;
    mapping(bytes32 => uint256) public decisionIdsByHash;
    uint256 public decisionCount;

    event DecisionLogged(uint256 indexed decisionId, uint256 indexed agentId, bytes32 decisionHash, uint8 riskLevel);
    event OutcomeUpdated(uint256 indexed decisionId, uint8 outcome);
    event OutcomeRecorded(
        uint256 indexed decisionId,
        bytes32 executionTxHash,
        int256 pnlBps,
        uint256 realizedApyBps,
        bool success,
        string metadataURI
    );

    function logDecision(
        uint256 agentId,
        bytes32 decisionHash,
        bytes32 strategyId,
        address targetProtocol,
        uint256 amount,
        uint8 riskLevel
    ) external returns (uint256) {
        uint256 id = ++decisionCount;
        decisions[id] = Decision(agentId, decisionHash, strategyId, targetProtocol, amount, riskLevel, 0, block.timestamp);
        decisionIdsByHash[decisionHash] = id;
        emit DecisionLogged(id, agentId, decisionHash, riskLevel);
        return id;
    }

    function updateOutcome(uint256 decisionId, uint8 outcome) external {
        require(decisions[decisionId].timestamp != 0, "decision not found");
        decisions[decisionId].outcome = outcome;
        emit OutcomeUpdated(decisionId, outcome);
    }

    function recordOutcome(
        uint256 decisionId,
        bytes32 executionTxHash,
        int256 pnlBps,
        uint256 realizedApyBps,
        uint256 inputAmount,
        uint256 outputAmount,
        bool success,
        string calldata metadataURI
    ) external {
        _recordOutcome(decisionId, executionTxHash, pnlBps, realizedApyBps, inputAmount, outputAmount, success, metadataURI);
    }

    function recordOutcomeForHash(
        bytes32 decisionHash,
        bytes32 executionTxHash,
        int256 pnlBps,
        uint256 realizedApyBps,
        uint256 inputAmount,
        uint256 outputAmount,
        bool success,
        string calldata metadataURI
    ) external {
        uint256 decisionId = decisionIdsByHash[decisionHash];
        require(decisionId != 0, "decision not found");
        _recordOutcome(decisionId, executionTxHash, pnlBps, realizedApyBps, inputAmount, outputAmount, success, metadataURI);
    }

    function _recordOutcome(
        uint256 decisionId,
        bytes32 executionTxHash,
        int256 pnlBps,
        uint256 realizedApyBps,
        uint256 inputAmount,
        uint256 outputAmount,
        bool success,
        string calldata metadataURI
    ) internal {
        require(decisions[decisionId].timestamp != 0, "decision not found");
        outcomes[decisionId] = Outcome({
            executionTxHash: executionTxHash,
            pnlBps: pnlBps,
            realizedApyBps: realizedApyBps,
            inputAmount: inputAmount,
            outputAmount: outputAmount,
            success: success,
            metadataURI: metadataURI,
            timestamp: block.timestamp
        });
        decisions[decisionId].outcome = success ? 1 : 2;
        emit OutcomeRecorded(decisionId, executionTxHash, pnlBps, realizedApyBps, success, metadataURI);
        emit OutcomeUpdated(decisionId, decisions[decisionId].outcome);
    }
}
