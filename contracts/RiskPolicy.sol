// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract RiskPolicy {
    struct Policy { address user; uint256 maxTxAmount; uint256 maxDailyLoss; uint8 maxRiskLevel; bool active; uint256 createdAt; }
    mapping(address => Policy) public userPolicies;
    event PolicySet(address indexed user, uint256 maxTxAmount, uint8 maxRiskLevel);
    event EmergencyPause(address indexed user);
    function setPolicy(uint256 maxTxAmount, uint256 maxDailyLoss, uint8 maxRiskLevel) external {
        userPolicies[msg.sender] = Policy(msg.sender, maxTxAmount, maxDailyLoss, maxRiskLevel, true, block.timestamp);
        emit PolicySet(msg.sender, maxTxAmount, maxRiskLevel);
    }
    function emergencyPause() external {
        userPolicies[msg.sender].active = false;
        emit EmergencyPause(msg.sender);
    }
    function checkPolicy(address user, uint256 amount, uint8 riskLevel) external view returns (bool) {
        Policy memory p = userPolicies[user];
        return p.active && amount <= p.maxTxAmount && riskLevel <= p.maxRiskLevel;
    }
}
