// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAgentIdentityOwner {
    function ownerOf(uint256 agentId) external view returns (address);
}

contract ValidationRegistry {
    struct ValidationStatus {
        address validatorAddress;
        uint256 agentId;
        uint8 response;
        bytes32 responseHash;
        string tag;
        uint256 lastUpdate;
        bool hasResponse;
    }

    IAgentIdentityOwner public immutable identityRegistry;
    mapping(bytes32 => ValidationStatus) private validations;
    mapping(uint256 => bytes32[]) private agentValidations;
    mapping(address => bytes32[]) private validatorRequests;

    event ValidationRequest(address indexed validatorAddress, uint256 indexed agentId, string requestURI, bytes32 indexed requestHash);
    event ValidationResponse(
        address indexed validatorAddress,
        uint256 indexed agentId,
        bytes32 indexed requestHash,
        uint8 response,
        string responseURI,
        bytes32 responseHash,
        string tag
    );

    constructor(address identityRegistry_) {
        require(identityRegistry_ != address(0), "bad identity");
        identityRegistry = IAgentIdentityOwner(identityRegistry_);
    }

    function validationRequest(address validatorAddress, uint256 agentId, string calldata requestURI, bytes32 requestHash) external {
        require(validatorAddress != address(0), "bad validator");
        require(requestHash != bytes32(0), "bad request");
        identityRegistry.ownerOf(agentId);
        ValidationStatus storage status = validations[requestHash];
        require(status.validatorAddress == address(0), "request exists");
        status.validatorAddress = validatorAddress;
        status.agentId = agentId;
        status.lastUpdate = block.timestamp;
        agentValidations[agentId].push(requestHash);
        validatorRequests[validatorAddress].push(requestHash);
        emit ValidationRequest(validatorAddress, agentId, requestURI, requestHash);
    }

    function validationResponse(
        uint256 agentId,
        bytes32 requestHash,
        uint8 response,
        string calldata responseURI,
        bytes32 responseHash,
        string calldata tag
    ) external {
        require(response <= 100, "bad response");
        ValidationStatus storage status = validations[requestHash];
        require(status.validatorAddress == msg.sender, "not validator");
        require(status.agentId == agentId, "agent mismatch");
        status.response = response;
        status.responseHash = responseHash;
        status.tag = tag;
        status.lastUpdate = block.timestamp;
        status.hasResponse = true;
        emit ValidationResponse(msg.sender, agentId, requestHash, response, responseURI, responseHash, tag);
    }

    function getValidation(bytes32 requestHash)
        external
        view
        returns (
            address validatorAddress,
            uint256 agentId,
            uint8 response,
            bytes32 responseHash,
            string memory tag,
            uint256 lastUpdate,
            bool hasResponse
        )
    {
        ValidationStatus storage status = validations[requestHash];
        return (
            status.validatorAddress,
            status.agentId,
            status.response,
            status.responseHash,
            status.tag,
            status.lastUpdate,
            status.hasResponse
        );
    }

    function getAgentValidations(uint256 agentId) external view returns (bytes32[] memory) {
        return agentValidations[agentId];
    }

    function getValidatorRequests(address validatorAddress) external view returns (bytes32[] memory) {
        return validatorRequests[validatorAddress];
    }
}
