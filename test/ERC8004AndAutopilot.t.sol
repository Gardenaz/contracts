// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {AgentIdentity} from "../contracts/AgentIdentity.sol";
import {AutopilotPolicy} from "../contracts/AutopilotPolicy.sol";

contract ERC8004AndAutopilotTest is Test {
    AgentIdentity identity;
    AutopilotPolicy autopilot;

    address agentOwner = address(0xA11CE);
    address user = address(0xB0B);
    address executor = address(0xCAFE);
    address protocolA = address(0x1001);
    address protocolB = address(0x1002);
    bytes32 steadyStrategy = keccak256("agni-usdy-defensive");
    bytes32 growthStrategy = keccak256("agni-meth-liquidity");

    function setUp() public {
        identity = new AgentIdentity();
        autopilot = new AutopilotPolicy();
    }

    function testRegistersERC8004AgentWithWalletAndMetadata() public {
        vm.prank(agentOwner);
        uint256 agentId = identity.registerAgent("Gardenaz Agent", "ipfs://gardenaz-agent", agentOwner);

        assertEq(agentId, 1);
        assertEq(identity.ownerOf(agentId), agentOwner);
        (address storedOwner,, , ,) = identity.agents(agentId);
        assertEq(storedOwner, agentOwner);
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

    function testAutopilotPolicyEnforcesRiskAmountIntervalAndAllowlist() public {
        address[] memory protocols = new address[](1);
        protocols[0] = protocolA;
        address[] memory executors = new address[](1);
        executors[0] = executor;
        bytes32[] memory strategies = new bytes32[](1);
        strategies[0] = steadyStrategy;

        vm.prank(user);
        autopilot.setAutopilotPolicy(1 ether, 0.2 ether, 2, 1 hours, 1 days, protocols, executors, strategies, true);

        assertTrue(autopilot.canExecute(user, executor, protocolA, steadyStrategy, 0.5 ether, 2));
        assertFalse(autopilot.canExecute(user, executor, protocolA, steadyStrategy, 2 ether, 2));
        assertFalse(autopilot.canExecute(user, executor, protocolA, steadyStrategy, 0.5 ether, 3));
        assertFalse(autopilot.canExecute(user, executor, protocolB, steadyStrategy, 0.5 ether, 2));
        assertFalse(autopilot.canExecute(user, address(0xF00D), protocolA, keccak256("steady"), 0.5 ether, 2));

        autopilot.setAuthorizedCaller(address(this), true);
        autopilot.recordExecution(user, executor, protocolA, steadyStrategy, 0.5 ether, 2, 0.1 ether);
        assertFalse(autopilot.canExecute(user, executor, protocolA, steadyStrategy, 0.5 ether, 2));

        vm.warp(block.timestamp + 1 hours + 1);
        assertTrue(autopilot.canExecute(user, executor, protocolA, steadyStrategy, 0.5 ether, 2));
    }

    function testPolicyListsResetBetweenVersions() public {
        address[] memory protocols = new address[](1);
        protocols[0] = protocolA;
        address[] memory executors = new address[](1);
        executors[0] = executor;
        bytes32[] memory strategies = new bytes32[](1);
        strategies[0] = steadyStrategy;

        vm.prank(user);
        autopilot.setAutopilotPolicy(1 ether, 0.2 ether, 2, 1 hours, 1 days, protocols, executors, strategies, true);

        address[] memory nextProtocols = new address[](1);
        nextProtocols[0] = protocolB;
        address[] memory nextExecutors = new address[](1);
        nextExecutors[0] = address(0xABCD);
        bytes32[] memory nextStrategies = new bytes32[](1);
        nextStrategies[0] = growthStrategy;

        vm.prank(user);
        autopilot.setAutopilotPolicy(2 ether, 0.5 ether, 3, 2 hours, 2 days, nextProtocols, nextExecutors, nextStrategies, true);

        assertFalse(autopilot.allowedProtocols(user, protocolA));
        assertFalse(autopilot.allowedExecutors(user, executor));
        assertFalse(autopilot.allowedStrategies(user, steadyStrategy));
        assertTrue(autopilot.allowedProtocols(user, protocolB));
        assertTrue(autopilot.allowedExecutors(user, address(0xABCD)));
        assertTrue(autopilot.allowedStrategies(user, growthStrategy));
        assertEq(autopilot.policyVersion(user), 2);
    }

    function testEmergencyPauseBlocksAutopilotUntilResumed() public {
        address[] memory protocols = new address[](1);
        protocols[0] = protocolA;
        address[] memory executors = new address[](1);
        executors[0] = executor;
        bytes32[] memory strategies = new bytes32[](1);
        strategies[0] = steadyStrategy;

        vm.prank(user);
        autopilot.setAutopilotPolicy(1 ether, 0.2 ether, 2, 1 hours, 1 days, protocols, executors, strategies, true);

        vm.prank(user);
        autopilot.emergencyPause();
        assertFalse(autopilot.canExecute(user, executor, protocolA, steadyStrategy, 0.5 ether, 1));

        vm.prank(user);
        autopilot.resumeAutopilot();
        assertTrue(autopilot.canExecute(user, executor, protocolA, steadyStrategy, 0.5 ether, 1));
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
        (address storedOwner,, , ,) = identity.agents(agentId);
        assertEq(storedOwner, user);
    }

    function testERC721SafeTransferFrom() public {
        vm.prank(agentOwner);
        uint256 agentId = identity.registerAgent("Gardenaz Agent", "ipfs://gardenaz-agent", agentOwner);

        vm.prank(agentOwner);
        identity.safeTransferFrom(agentOwner, user, agentId);
        assertEq(identity.ownerOf(agentId), user);
        (address storedOwner,, , ,) = identity.agents(agentId);
        assertEq(storedOwner, user);
    }

    function testOnlyContractOwnerCanUpdateReputation() public {
        vm.prank(agentOwner);
        uint256 agentId = identity.registerAgent("Gardenaz Agent", "ipfs://gardenaz-agent", agentOwner);

        vm.prank(user);
        vm.expectRevert();
        identity.updateReputation(agentId, 88);

        identity.updateReputation(agentId, 88);
        assertEq(identity.reputationScore(agentId), 88);
    }

    function testIncrementalAllowlistsDoNotDuplicateEntriesAcrossToggles() public {
        vm.startPrank(user);
        autopilot.setProtocolAllowed(protocolA, true);
        autopilot.setProtocolAllowed(protocolA, false);
        autopilot.setProtocolAllowed(protocolA, true);

        autopilot.setExecutorAllowed(executor, true);
        autopilot.setExecutorAllowed(executor, false);
        autopilot.setExecutorAllowed(executor, true);

        autopilot.setStrategyAllowed(steadyStrategy, true);
        autopilot.setStrategyAllowed(steadyStrategy, false);
        autopilot.setStrategyAllowed(steadyStrategy, true);
        vm.stopPrank();

        address[] memory protocols = autopilot.protocolListOf(user);
        address[] memory executors = autopilot.executorListOf(user);
        bytes32[] memory strategies = autopilot.strategyListOf(user);

        assertEq(protocols.length, 1);
        assertEq(protocols[0], protocolA);
        assertEq(executors.length, 1);
        assertEq(executors[0], executor);
        assertEq(strategies.length, 1);
        assertEq(strategies[0], steadyStrategy);
    }

    function testPolicyReplacementDeduplicatesInputLists() public {
        address[] memory protocols = new address[](2);
        protocols[0] = protocolA;
        protocols[1] = protocolA;
        address[] memory executors = new address[](2);
        executors[0] = executor;
        executors[1] = executor;
        bytes32[] memory strategies = new bytes32[](2);
        strategies[0] = steadyStrategy;
        strategies[1] = steadyStrategy;

        vm.prank(user);
        autopilot.setAutopilotPolicy(1 ether, 0.2 ether, 2, 1 hours, 1 days, protocols, executors, strategies, true);

        address[] memory storedProtocols = autopilot.protocolListOf(user);
        address[] memory storedExecutors = autopilot.executorListOf(user);
        bytes32[] memory storedStrategies = autopilot.strategyListOf(user);

        assertEq(storedProtocols.length, 1);
        assertEq(storedProtocols[0], protocolA);
        assertEq(storedExecutors.length, 1);
        assertEq(storedExecutors[0], executor);
        assertEq(storedStrategies.length, 1);
        assertEq(storedStrategies[0], steadyStrategy);
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
