// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721, ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract AgentIdentity is ERC721URIStorage {
    struct Agent {
        address owner;
        string name;
        string metadataURI;
        uint256 createdAt;
        bool active;
    }

    mapping(uint256 => Agent) public agents;
    mapping(uint256 => uint256) public reputationScore;
    mapping(uint256 => mapping(string => bytes)) private _agentMetadata;
    uint256 public agentCount;

    event AgentRegistered(uint256 indexed agentId, address indexed owner, string name);
    event AgentURIUpdated(uint256 indexed agentId, string uri, address indexed updatedBy);
    event MetadataSet(uint256 indexed agentId, string indexed indexedMetadataKey, string metadataKey, bytes metadataValue);
    event ReputationUpdated(uint256 indexed agentId, uint256 score);

    constructor() ERC721("Gardenaz Agent Identity", "GARDENAZ") {}

    modifier onlyExisting(uint256 agentId) {
        require(_ownerOf(agentId) != address(0), "agent not found");
        _;
    }

    modifier onlyAuthorized(uint256 agentId) {
        require(_isAuthorizedOrOwner(msg.sender, agentId), "not authorized");
        _;
    }

    function registerAgent(string calldata name, string calldata metadataURI_) external returns (uint256) {
        return registerAgent(name, metadataURI_, msg.sender);
    }

    function registerAgent(
        string calldata name,
        string calldata metadataURI_,
        address agentWallet
    ) public returns (uint256) {
        require(agentWallet != address(0), "bad wallet");
        uint256 id = ++agentCount;
        agents[id] = Agent(msg.sender, name, metadataURI_, block.timestamp, true);
        _agentMetadata[id]["agentWallet"] = abi.encodePacked(agentWallet);
        _safeMint(msg.sender, id);
        _setTokenURI(id, metadataURI_);
        emit AgentRegistered(id, msg.sender, name);
        emit AgentURIUpdated(id, metadataURI_, msg.sender);
        emit MetadataSet(id, "agentWallet", "agentWallet", abi.encodePacked(agentWallet));
        return id;
    }

    function agentURI(uint256 agentId) external view onlyExisting(agentId) returns (string memory) {
        return agents[agentId].metadataURI;
    }

    function setAgentURI(uint256 agentId, string calldata newURI) external onlyExisting(agentId) onlyAuthorized(agentId) {
        agents[agentId].metadataURI = newURI;
        _setTokenURI(agentId, newURI);
        emit AgentURIUpdated(agentId, newURI, msg.sender);
    }

    function setMetadata(uint256 agentId, string calldata key, bytes calldata value) external onlyExisting(agentId) onlyAuthorized(agentId) {
        _agentMetadata[agentId][key] = value;
        emit MetadataSet(agentId, key, key, value);
    }

    function getMetadata(uint256 agentId, string calldata key) external view onlyExisting(agentId) returns (bytes memory) {
        return _agentMetadata[agentId][key];
    }

    function setActive(uint256 agentId, bool active) external onlyExisting(agentId) onlyAuthorized(agentId) {
        agents[agentId].active = active;
    }

    function updateReputation(uint256 agentId, uint256 score) external onlyExisting(agentId) {
        reputationScore[agentId] = score;
        emit ReputationUpdated(agentId, score);
    }

    function isAuthorizedOrOwner(address spender, uint256 agentId) public view onlyExisting(agentId) returns (bool) {
        return _isAuthorizedOrOwner(spender, agentId);
    }

    function totalSupply() external view returns (uint256) {
        return agentCount;
    }

    function _isAuthorizedOrOwner(address spender, uint256 agentId) internal view onlyExisting(agentId) returns (bool) {
        address tokenOwner = ownerOf(agentId);
        return spender == tokenOwner || getApproved(agentId) == spender || isApprovedForAll(tokenOwner, spender);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721URIStorage) returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
