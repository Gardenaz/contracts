// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAgentIdentityAuth {
    function isAuthorizedOrOwner(address spender, uint256 agentId) external view returns (bool);
    function ownerOf(uint256 agentId) external view returns (address);
}

contract ReputationRegistry {
    struct Feedback {
        int128 value;
        uint8 valueDecimals;
        bool isRevoked;
        string tag1;
        string tag2;
    }

    IAgentIdentityAuth public immutable identityRegistry;

    mapping(uint256 => mapping(address => mapping(uint64 => Feedback))) private feedback;
    mapping(uint256 => mapping(address => uint64)) public lastFeedbackIndex;
    mapping(uint256 => mapping(address => mapping(uint64 => mapping(address => uint64)))) public responseCount;

    event NewFeedback(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint64 feedbackIndex,
        int128 value,
        uint8 valueDecimals,
        string indexed indexedTag1,
        string tag1,
        string tag2,
        string endpoint,
        string feedbackURI,
        bytes32 feedbackHash
    );
    event FeedbackRevoked(uint256 indexed agentId, address indexed clientAddress, uint64 indexed feedbackIndex);
    event ResponseAppended(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint64 feedbackIndex,
        address indexed responder,
        string responseURI,
        bytes32 responseHash
    );

    constructor(address identityRegistry_) {
        require(identityRegistry_ != address(0), "bad identity");
        identityRegistry = IAgentIdentityAuth(identityRegistry_);
    }

    function giveFeedback(
        uint256 agentId,
        int128 value,
        uint8 valueDecimals,
        string calldata tag1,
        string calldata tag2,
        string calldata endpoint,
        string calldata feedbackURI,
        bytes32 feedbackHash
    ) external returns (uint64 feedbackIndex) {
        identityRegistry.ownerOf(agentId);
        feedbackIndex = ++lastFeedbackIndex[agentId][msg.sender];
        feedback[agentId][msg.sender][feedbackIndex] = Feedback(value, valueDecimals, false, tag1, tag2);
        _emitFeedback(agentId, msg.sender, feedbackIndex, value, valueDecimals, tag1, tag2, endpoint, feedbackURI, feedbackHash);
    }

    function _emitFeedback(
        uint256 agentId,
        address clientAddress,
        uint64 feedbackIndex,
        int128 value,
        uint8 valueDecimals,
        string calldata tag1,
        string calldata tag2,
        string calldata endpoint,
        string calldata feedbackURI,
        bytes32 feedbackHash
    ) private {
        emit NewFeedback(agentId, clientAddress, feedbackIndex, value, valueDecimals, tag1, tag1, tag2, endpoint, feedbackURI, feedbackHash);
    }

    function revokeFeedback(uint256 agentId, uint64 feedbackIndex) external {
        Feedback storage item = feedback[agentId][msg.sender][feedbackIndex];
        require(feedbackIndex != 0 && feedbackIndex <= lastFeedbackIndex[agentId][msg.sender], "bad feedback");
        item.isRevoked = true;
        emit FeedbackRevoked(agentId, msg.sender, feedbackIndex);
    }

    function appendResponse(
        uint256 agentId,
        address clientAddress,
        uint64 feedbackIndex,
        string calldata responseURI,
        bytes32 responseHash
    ) external {
        require(identityRegistry.isAuthorizedOrOwner(msg.sender, agentId), "not authorized");
        require(feedbackIndex != 0 && feedbackIndex <= lastFeedbackIndex[agentId][clientAddress], "bad feedback");
        responseCount[agentId][clientAddress][feedbackIndex][msg.sender] += 1;
        emit ResponseAppended(agentId, clientAddress, feedbackIndex, msg.sender, responseURI, responseHash);
    }

    function getFeedback(uint256 agentId, address clientAddress, uint64 feedbackIndex)
        external
        view
        returns (int128 value, uint8 valueDecimals, bool isRevoked, string memory tag1, string memory tag2)
    {
        Feedback storage item = feedback[agentId][clientAddress][feedbackIndex];
        return (item.value, item.valueDecimals, item.isRevoked, item.tag1, item.tag2);
    }
}
