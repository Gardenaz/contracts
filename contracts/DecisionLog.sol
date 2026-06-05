// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DecisionLog is Ownable {
    struct Decision {
        uint256 agentId;
        bytes32 decisionHash;
        bytes32 strategyId;
        address targetProtocol;
        uint256 amount;
        uint8 riskLevel;
        uint8 outcome;
        uint256 timestamp;
        address user;
        uint256 positionId;
        uint256 policyVersion;
        address executor;
    }

    struct Outcome {
        bytes32 executionTxHash;
        int256 pnlBps;
        uint256 realizedApyBps;
        uint256 inputAmount;
        uint256 outputAmount;
        bool success;
        bool finalized;
        string metadataURI;
        uint256 timestamp;
    }

    mapping(uint256 => Decision) public decisions;
    mapping(uint256 => Outcome) public outcomes;
    mapping(bytes32 => uint256) public decisionIdsByHash;
    mapping(address => bool) public writers;
    uint256 public decisionCount;

    event WriterUpdated(address indexed writer, bool allowed);
    event DecisionLogged(
        uint256 indexed decisionId,
        uint256 indexed agentId,
        bytes32 indexed decisionHash,
        address user,
        uint256 positionId,
        uint256 policyVersion,
        address executor,
        uint8 riskLevel
    );
    event OutcomeRecorded(
        uint256 indexed decisionId,
        bytes32 executionTxHash,
        int256 pnlBps,
        uint256 realizedApyBps,
        bool success,
        string metadataURI
    );

    constructor() Ownable(msg.sender) {}

    modifier onlyWriter() {
        require(writers[msg.sender], "not writer");
        _;
    }

    function setWriter(address writer, bool allowed) external onlyOwner {
        require(writer != address(0), "bad writer");
        writers[writer] = allowed;
        emit WriterUpdated(writer, allowed);
    }

    function logDecision(
        uint256 agentId,
        bytes32 decisionHash,
        bytes32 strategyId,
        address targetProtocol,
        uint256 amount,
        uint8 riskLevel,
        address user,
        uint256 positionId,
        uint256 policyVersion,
        address executor
    ) external onlyWriter returns (uint256) {
        require(decisionHash != bytes32(0), "bad hash");
        require(user != address(0), "bad user");
        require(targetProtocol != address(0), "bad protocol");
        require(executor != address(0), "bad executor");
        require(decisionIdsByHash[decisionHash] == 0, "decision exists");

        uint256 id = ++decisionCount;
        decisions[id] = Decision({
            agentId: agentId,
            decisionHash: decisionHash,
            strategyId: strategyId,
            targetProtocol: targetProtocol,
            amount: amount,
            riskLevel: riskLevel,
            outcome: 0,
            timestamp: block.timestamp,
            user: user,
            positionId: positionId,
            policyVersion: policyVersion,
            executor: executor
        });
        decisionIdsByHash[decisionHash] = id;
        emit DecisionLogged(id, agentId, decisionHash, user, positionId, policyVersion, executor, riskLevel);
        return id;
    }

    function recordOutcomeForDecision(
        uint256 decisionId,
        bytes32 executionTxHash,
        int256 pnlBps,
        uint256 realizedApyBps,
        uint256 inputAmount,
        uint256 outputAmount,
        bool success,
        string calldata metadataURI
    ) external onlyWriter {
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
    ) external onlyWriter {
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
        require(!outcomes[decisionId].finalized, "outcome finalized");
        outcomes[decisionId] = Outcome({
            executionTxHash: executionTxHash,
            pnlBps: pnlBps,
            realizedApyBps: realizedApyBps,
            inputAmount: inputAmount,
            outputAmount: outputAmount,
            success: success,
            finalized: true,
            metadataURI: metadataURI,
            timestamp: block.timestamp
        });
        decisions[decisionId].outcome = success ? 1 : 2;
        emit OutcomeRecorded(decisionId, executionTxHash, pnlBps, realizedApyBps, success, metadataURI);
    }
}
