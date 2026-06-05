// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {AgentIdentity} from "../contracts/AgentIdentity.sol";
import {ReputationRegistry} from "../contracts/ReputationRegistry.sol";
import {ValidationRegistry} from "../contracts/ValidationRegistry.sol";
import {AutopilotPolicy} from "../contracts/AutopilotPolicy.sol";

contract ERC8004AndAutopilotTest is Test {
    AgentIdentity identity;
    ReputationRegistry reputation;
    ValidationRegistry validation;
    AutopilotPolicy autopilot;

    address agentOwner = address(0xA11CE);
    address user = address(0xB0B);
    address validator = address(0xCAFE);
    address protocolA = address(0x1001);
    address protocolB = address(0x1002);

    function setUp() public {
        identity = new AgentIdentity();
        reputation = new ReputationRegistry(address(identity));
        validation = new ValidationRegistry(address(identity));
        autopilot = new AutopilotPolicy();
    }

    function testRegistersERC8004AgentWithWalletAndMetadata() public {
        vm.prank(agentOwner);
        uint256 agentId = identity.registerAgent("Gardenaz Agent", "ipfs://gardenaz-agent", agentOwner);

        assertEq(agentId, 1);
        assertEq(identity.ownerOf(agentId), agentOwner);
        assertEq(identity.agentURI(agentId), "ipfs://gardenaz-agent");
        assertEq(identity.getMetadata(agentId, "agentWallet"), abi.encodePacked(agentOwner));
        assertTrue(identity.isAuthorizedOrOwner(agentOwner, agentId));
    }

    function testOwnerCanSetERC8004MetadataButStrangerCannot() public {
        vm.prank(agentOwner);
        uint256 agentId = identity.registerAgent("Gardenaz Agent", "ipfs://gardenaz-agent", agentOwner);

        vm.prank(agentOwner);
        identity.setMetadata(agentId, "endpoint", bytes("https://agent.gardenaz.xyz"));
        assertEq(identity.getMetadata(agentId, "endpoint"), bytes("https://agent.gardenaz.xyz"));

        vm.prank(user);
        vm.expectRevert("not authorized");
        identity.setMetadata(agentId, "endpoint", bytes("https://evil.example"));
    }

    function testReputationRegistryStoresFeedbackAndResponses() public {
        vm.prank(agentOwner);
        uint256 agentId = identity.registerAgent("Gardenaz Agent", "ipfs://gardenaz-agent", agentOwner);

        bytes32 feedbackHash = keccak256("rice-pass-feedback");
        vm.prank(user);
        uint64 index = reputation.giveFeedback(
            agentId,
            85,
            0,
            "yield",
            "rice",
            "https://app.gardenaz.xyz/diary/1",
            "ipfs://feedback-1",
            feedbackHash
        );

        assertEq(index, 1);
        (int128 value, uint8 decimals, bool revoked, string memory tag1, string memory tag2) =
            reputation.getFeedback(agentId, user, index);
        assertEq(value, 85);
        assertEq(decimals, 0);
        assertFalse(revoked);
        assertEq(tag1, "yield");
        assertEq(tag2, "rice");

        vm.prank(agentOwner);
        reputation.appendResponse(agentId, user, index, "ipfs://agent-response", keccak256("response"));
        assertEq(reputation.responseCount(agentId, user, index, agentOwner), 1);
    }

    function testValidationRequestAndResponseLifecycle() public {
        vm.prank(agentOwner);
        uint256 agentId = identity.registerAgent("Gardenaz Agent", "ipfs://gardenaz-agent", agentOwner);

        bytes32 requestHash = keccak256("validate-decision-1");
        vm.prank(user);
        validation.validationRequest(validator, agentId, "ipfs://validation-request", requestHash);

        vm.prank(validator);
        validation.validationResponse(
            agentId,
            requestHash,
            92,
            "ipfs://validation-response",
            keccak256("safe"),
            "policy-safe"
        );

        (address storedValidator, uint256 storedAgentId, uint8 response, bytes32 responseHash, string memory tag, , bool hasResponse) =
            validation.getValidation(requestHash);
        assertEq(storedValidator, validator);
        assertEq(storedAgentId, agentId);
        assertEq(response, 92);
        assertEq(responseHash, keccak256("safe"));
        assertEq(tag, "policy-safe");
        assertTrue(hasResponse);
    }

    function testAutopilotPolicyEnforcesRiskAmountIntervalAndAllowlist() public {
        address[] memory protocols = new address[](1);
        protocols[0] = protocolA;
        address[] memory executors = new address[](1);
        executors[0] = validator;
        bytes32[] memory strategies = new bytes32[](1);
        strategies[0] = keccak256("steady");

        vm.prank(user);
        autopilot.setAutopilotPolicy(1 ether, 0.2 ether, 2, 1 hours, 1 days, protocols, executors, strategies, true);

        assertTrue(autopilot.canExecute(user, validator, protocolA, keccak256("steady"), 0.5 ether, 2));
        assertFalse(autopilot.canExecute(user, validator, protocolA, keccak256("steady"), 2 ether, 2));
        assertFalse(autopilot.canExecute(user, validator, protocolA, keccak256("steady"), 0.5 ether, 3));
        assertFalse(autopilot.canExecute(user, validator, protocolB, keccak256("steady"), 0.5 ether, 2));
        assertFalse(autopilot.canExecute(user, address(0xF00D), protocolA, keccak256("steady"), 0.5 ether, 2));

        autopilot.setAuthorizedVault(address(this), true);
        autopilot.recordExecution(user, validator, protocolA, keccak256("steady"), 0.5 ether, 2, 0.1 ether);
        assertFalse(autopilot.canExecute(user, validator, protocolA, keccak256("steady"), 0.5 ether, 2));

        vm.warp(block.timestamp + 1 hours + 1);
        assertTrue(autopilot.canExecute(user, validator, protocolA, keccak256("steady"), 0.5 ether, 2));
    }

    function testEmergencyPauseBlocksAutopilot() public {
        address[] memory protocols = new address[](1);
        protocols[0] = protocolA;
        address[] memory executors = new address[](1);
        executors[0] = validator;
        bytes32[] memory strategies = new bytes32[](1);
        strategies[0] = keccak256("steady");

        vm.prank(user);
        autopilot.setAutopilotPolicy(1 ether, 0.2 ether, 2, 1 hours, 1 days, protocols, executors, strategies, true);

        vm.prank(user);
        autopilot.emergencyPause();

        assertFalse(autopilot.canExecute(user, validator, protocolA, keccak256("steady"), 0.5 ether, 1));
    }

    // ── ERC-721 compliance ──

    function testERC721NameAndSymbol() public {
        assertEq(identity.name(), "Gardenaz Agent Identity");
        assertEq(identity.symbol(), "GARDENAZ");
    }

    function testERC721Transfer() public {
        vm.prank(agentOwner);
        uint256 agentId = identity.registerAgent("Gardenaz Agent", "ipfs://gardenaz-agent", agentOwner);

        vm.prank(agentOwner);
        identity.transferFrom(agentOwner, user, agentId);
        assertEq(identity.ownerOf(agentId), user);
    }

    function testERC721SafeTransferFrom() public {
        vm.prank(agentOwner);
        uint256 agentId = identity.registerAgent("Gardenaz Agent", "ipfs://gardenaz-agent", agentOwner);

        vm.prank(agentOwner);
        identity.safeTransferFrom(agentOwner, user, agentId);
        assertEq(identity.ownerOf(agentId), user);
    }

    function testERC721BalanceAndTotalSupply() public {
        vm.prank(agentOwner);
        identity.registerAgent("Agent A", "ipfs://a", agentOwner);
        vm.prank(agentOwner);
        identity.registerAgent("Agent B", "ipfs://b", agentOwner);

        assertEq(identity.balanceOf(agentOwner), 2);
        assertEq(identity.totalSupply(), 2);
    }

    function testERC721TokenURIMatchesAgentCardURI() public {
        vm.prank(agentOwner);
        uint256 agentId = identity.registerAgent("Gardenaz Agent", "ipfs://gardenaz-agent-card", agentOwner);

        assertEq(identity.tokenURI(agentId), "ipfs://gardenaz-agent-card");
        assertEq(identity.agentURI(agentId), "ipfs://gardenaz-agent-card");
    }

    function testSetAgentURIUpdatesBothAgentURIAndTokenURI() public {
        vm.prank(agentOwner);
        uint256 agentId = identity.registerAgent("Gardenaz Agent", "ipfs://v1", agentOwner);

        vm.prank(agentOwner);
        identity.setAgentURI(agentId, "ipfs://v2");

        assertEq(identity.agentURI(agentId), "ipfs://v2");
        assertEq(identity.tokenURI(agentId), "ipfs://v2");
    }

    function testERC165SupportsInterface() public {
        // ERC-165
        assertTrue(identity.supportsInterface(0x01ffc9a7));
        // ERC-721
        assertTrue(identity.supportsInterface(0x80ac58cd));
        // ERC-721Metadata
        assertTrue(identity.supportsInterface(0x5b5e139f));
    }
}
