// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract AgentIdentity {
    struct Agent {
        address owner;
        string name;
        string metadataURI;
        uint256 createdAt;
        bool active;
    }

    mapping(uint256 => Agent) public agents;
    mapping(uint256 => uint256) public reputationScore;
    mapping(uint256 => mapping(string => bytes)) private metadata;
    mapping(uint256 => address) private tokenApprovals;
    mapping(address => mapping(address => bool)) private operatorApprovals;
    uint256 public agentCount;

    event AgentRegistered(uint256 indexed agentId, address indexed owner, string name);
    event Registered(uint256 indexed agentId, string agentURI, address indexed owner);
    event MetadataSet(uint256 indexed agentId, string indexed indexedMetadataKey, string metadataKey, bytes metadataValue);
    event URIUpdated(uint256 indexed agentId, string newURI, address indexed updatedBy);
    event ReputationUpdated(uint256 indexed agentId, uint256 score);
    event Approval(address indexed owner, address indexed approved, uint256 indexed agentId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    modifier onlyExisting(uint256 agentId) {
        require(agents[agentId].owner != address(0), "agent not found");
        _;
    }

    modifier onlyAuthorized(uint256 agentId) {
        require(isAuthorizedOrOwner(msg.sender, agentId), "not authorized");
        _;
    }

    function registerAgent(string calldata name, string calldata metadataURI) external returns (uint256) {
        return registerAgent(name, metadataURI, msg.sender);
    }

    function registerAgent(string calldata name, string calldata metadataURI, address agentWallet) public returns (uint256) {
        require(agentWallet != address(0), "bad wallet");
        uint256 id = ++agentCount;
        agents[id] = Agent(msg.sender, name, metadataURI, block.timestamp, true);
        metadata[id]["agentWallet"] = abi.encodePacked(agentWallet);
        emit AgentRegistered(id, msg.sender, name);
        emit Registered(id, metadataURI, msg.sender);
        emit MetadataSet(id, "agentWallet", "agentWallet", abi.encodePacked(agentWallet));
        return id;
    }

    function ownerOf(uint256 agentId) public view onlyExisting(agentId) returns (address) {
        return agents[agentId].owner;
    }

    function agentURI(uint256 agentId) external view onlyExisting(agentId) returns (string memory) {
        return agents[agentId].metadataURI;
    }

    function setAgentURI(uint256 agentId, string calldata newURI) external onlyExisting(agentId) onlyAuthorized(agentId) {
        agents[agentId].metadataURI = newURI;
        emit URIUpdated(agentId, newURI, msg.sender);
    }

    function setMetadata(uint256 agentId, string calldata key, bytes calldata value) external onlyExisting(agentId) onlyAuthorized(agentId) {
        metadata[agentId][key] = value;
        emit MetadataSet(agentId, key, key, value);
    }

    function getMetadata(uint256 agentId, string calldata key) external view onlyExisting(agentId) returns (bytes memory) {
        return metadata[agentId][key];
    }

    function approve(address to, uint256 agentId) external onlyExisting(agentId) onlyAuthorized(agentId) {
        tokenApprovals[agentId] = to;
        emit Approval(agents[agentId].owner, to, agentId);
    }

    function getApproved(uint256 agentId) public view onlyExisting(agentId) returns (address) {
        return tokenApprovals[agentId];
    }

    function setApprovalForAll(address operator, bool approved) external {
        operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return operatorApprovals[owner][operator];
    }

    function isAuthorizedOrOwner(address spender, uint256 agentId) public view onlyExisting(agentId) returns (bool) {
        address owner = agents[agentId].owner;
        return spender == owner || getApproved(agentId) == spender || isApprovedForAll(owner, spender);
    }

    function setActive(uint256 agentId, bool active) external onlyExisting(agentId) onlyAuthorized(agentId) {
        agents[agentId].active = active;
    }

    function updateReputation(uint256 agentId, uint256 score) external onlyExisting(agentId) {
        reputationScore[agentId] = score;
        emit ReputationUpdated(agentId, score);
    }
}
