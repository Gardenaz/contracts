// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {AgentIdentity} from "../contracts/AgentIdentity.sol";
import {DecisionLog} from "../contracts/DecisionLog.sol";
import {RiskPolicy} from "../contracts/RiskPolicy.sol";

contract StarterTest is Test {
    function testDeployAll() public {
        AgentIdentity a = new AgentIdentity();
        DecisionLog d = new DecisionLog();
        RiskPolicy r = new RiskPolicy();

        assertTrue(address(a) != address(0));
        assertTrue(address(d) != address(0));
        assertTrue(address(r) != address(0));
    }
}
