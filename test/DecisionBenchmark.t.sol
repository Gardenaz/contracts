// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {DecisionLog} from "../contracts/DecisionLog.sol";

contract DecisionBenchmarkTest is Test {
    DecisionLog decisionLog;

    function setUp() public {
        decisionLog = new DecisionLog();
    }

    function testRecordsOutcomeWithExecutionBenchmarkFields() public {
        uint256 decisionId = decisionLog.logDecision(
            1,
            keccak256("decision"),
            keccak256("steady-rwa-usdy"),
            address(0x1001),
            1 ether,
            1
        );

        decisionLog.recordOutcome(
            decisionId,
            bytes32(uint256(0xabc)),
            125,
            520,
            1000 ether,
            1001 ether,
            true,
            "ipfs://outcome-1"
        );

        (
            bytes32 executionTxHash,
            int256 pnlBps,
            uint256 realizedApyBps,
            uint256 inputAmount,
            uint256 outputAmount,
            bool success,
            string memory metadataURI,
            uint256 timestamp
        ) = decisionLog.outcomes(decisionId);

        assertEq(executionTxHash, bytes32(uint256(0xabc)));
        assertEq(pnlBps, 125);
        assertEq(realizedApyBps, 520);
        assertEq(inputAmount, 1000 ether);
        assertEq(outputAmount, 1001 ether);
        assertTrue(success);
        assertEq(metadataURI, "ipfs://outcome-1");
        assertGt(timestamp, 0);
    }

    function testRecordsOutcomeByDecisionHash() public {
        bytes32 decisionHash = keccak256("decision-by-hash");
        decisionLog.logDecision(1, decisionHash, keccak256("strategy"), address(0x1001), 1 ether, 1);

        decisionLog.recordOutcomeForHash(decisionHash, bytes32(uint256(0xdef)), 10, 500, 1 ether, 2 ether, true, "ipfs://hash-outcome");

        uint256 decisionId = decisionLog.decisionIdsByHash(decisionHash);
        (bytes32 executionTxHash, int256 pnlBps, , , , bool success, string memory metadataURI, ) = decisionLog.outcomes(decisionId);
        assertEq(executionTxHash, bytes32(uint256(0xdef)));
        assertEq(pnlBps, 10);
        assertTrue(success);
        assertEq(metadataURI, "ipfs://hash-outcome");
    }

    function testCannotRecordOutcomeForMissingDecision() public {
        vm.expectRevert("decision not found");
        decisionLog.recordOutcome(999, bytes32(uint256(1)), 0, 0, 0, 0, false, "ipfs://missing");
    }
}
