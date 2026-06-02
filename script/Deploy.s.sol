// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {AgentIdentity} from "../contracts/AgentIdentity.sol";
import {AutopilotPolicy} from "../contracts/AutopilotPolicy.sol";
import {DecisionLog} from "../contracts/DecisionLog.sol";
import {ReputationRegistry} from "../contracts/ReputationRegistry.sol";
import {RiskPolicy} from "../contracts/RiskPolicy.sol";
import {ValidationRegistry} from "../contracts/ValidationRegistry.sol";

contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();

        AgentIdentity agentIdentity = new AgentIdentity();
        DecisionLog decisionLog = new DecisionLog();
        RiskPolicy riskPolicy = new RiskPolicy();
        ReputationRegistry reputationRegistry = new ReputationRegistry(address(agentIdentity));
        ValidationRegistry validationRegistry = new ValidationRegistry(address(agentIdentity));
        AutopilotPolicy autopilotPolicy = new AutopilotPolicy();

        vm.stopBroadcast();

        console2.log("AgentIdentity:", address(agentIdentity));
        console2.log("DecisionLog:", address(decisionLog));
        console2.log("RiskPolicy:", address(riskPolicy));
        console2.log("ReputationRegistry:", address(reputationRegistry));
        console2.log("ValidationRegistry:", address(validationRegistry));
        console2.log("AutopilotPolicy:", address(autopilotPolicy));
    }
}
