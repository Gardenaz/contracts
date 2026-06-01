// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract AgentIdentity {
    struct Agent { address owner; string name; string metadataURI; uint256 createdAt; bool active; }
    mapping(uint256 => Agent) public agents;
    mapping(uint256 => uint256) public reputationScore;
    uint256 public agentCount;
    event AgentRegistered(uint256 indexed agentId, address owner, string name);
    event ReputationUpdated(uint256 indexed agentId, uint256 score);
    function registerAgent(string calldata name, string calldata metadataURI) external returns (uint256) {
        uint256 id = ++agentCount;
        agents[id] = Agent(msg.sender, name, metadataURI, block.timestamp, true);
        emit AgentRegistered(id, msg.sender, name);
        return id;
    }
    function updateReputation(uint256 agentId, uint256 score) external {
        reputationScore[agentId] = score;
        emit ReputationUpdated(agentId, score);
    }
}
