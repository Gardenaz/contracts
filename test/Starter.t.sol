// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {AgentIdentity} from "../contracts/AgentIdentity.sol";
import {AutopilotPolicy} from "../contracts/AutopilotPolicy.sol";
import {DecisionLog} from "../contracts/DecisionLog.sol";

contract StarterTest is Test {
    function testCoreContractsDeploy() public {
        AgentIdentity identity = new AgentIdentity();
        AutopilotPolicy policy = new AutopilotPolicy();
        DecisionLog log = new DecisionLog();

        assertTrue(address(identity) != address(0));
        assertTrue(address(policy) != address(0));
        assertTrue(address(log) != address(0));
    }
}
