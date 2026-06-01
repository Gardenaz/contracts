// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {AgentIdentity} from "../contracts/AgentIdentity.sol";
import {DecisionLog} from "../contracts/DecisionLog.sol";
import {RiskPolicy} from "../contracts/RiskPolicy.sol";

contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();

        AgentIdentity agentIdentity = new AgentIdentity();
        DecisionLog decisionLog = new DecisionLog();
        RiskPolicy riskPolicy = new RiskPolicy();

        vm.stopBroadcast();

        console2.log("AgentIdentity:", address(agentIdentity));
        console2.log("DecisionLog:", address(decisionLog));
        console2.log("RiskPolicy:", address(riskPolicy));
    }
}
