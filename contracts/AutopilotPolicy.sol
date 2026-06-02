// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract AutopilotPolicy {
    struct Policy {
        uint256 maxTxAmount;
        uint256 maxDailyLoss;
        uint8 maxRiskLevel;
        uint256 rebalanceInterval;
        bool enabled;
        bool emergencyPaused;
        uint256 lastExecutionAt;
        uint256 dailyLossUsed;
        uint256 dailyWindowStartedAt;
    }

    mapping(address => Policy) public policies;
    mapping(address => mapping(address => bool)) public allowedProtocols;

    event AutopilotPolicySet(
        address indexed user,
        uint256 maxTxAmount,
        uint256 maxDailyLoss,
        uint8 maxRiskLevel,
        uint256 rebalanceInterval,
        bool enabled
    );
    event ProtocolAllowed(address indexed user, address indexed protocol, bool allowed);
    event AutopilotExecutionRecorded(address indexed user, uint256 lossAmount, uint256 timestamp);
    event EmergencyPause(address indexed user);
    event AutopilotResumed(address indexed user);

    function setAutopilotPolicy(
        uint256 maxTxAmount,
        uint256 maxDailyLoss,
        uint8 maxRiskLevel,
        uint256 rebalanceInterval,
        address[] calldata protocols,
        bool enabled
    ) external {
        require(maxRiskLevel >= 1 && maxRiskLevel <= 3, "bad risk");
        require(rebalanceInterval > 0, "bad interval");
        Policy storage policy = policies[msg.sender];
        policy.maxTxAmount = maxTxAmount;
        policy.maxDailyLoss = maxDailyLoss;
        policy.maxRiskLevel = maxRiskLevel;
        policy.rebalanceInterval = rebalanceInterval;
        policy.enabled = enabled;
        policy.emergencyPaused = false;
        if (policy.dailyWindowStartedAt == 0) {
            policy.dailyWindowStartedAt = block.timestamp;
        }

        for (uint256 i = 0; i < protocols.length; i++) {
            require(protocols[i] != address(0), "bad protocol");
            allowedProtocols[msg.sender][protocols[i]] = true;
            emit ProtocolAllowed(msg.sender, protocols[i], true);
        }

        emit AutopilotPolicySet(msg.sender, maxTxAmount, maxDailyLoss, maxRiskLevel, rebalanceInterval, enabled);
    }

    function setProtocolAllowed(address protocol, bool allowed) external {
        require(protocol != address(0), "bad protocol");
        allowedProtocols[msg.sender][protocol] = allowed;
        emit ProtocolAllowed(msg.sender, protocol, allowed);
    }

    function canExecute(address user, uint256 amount, uint8 riskLevel, address protocol) public view returns (bool) {
        Policy memory policy = policies[user];
        return policy.enabled && !policy.emergencyPaused && amount <= policy.maxTxAmount && riskLevel <= policy.maxRiskLevel
            && allowedProtocols[user][protocol]
            && (policy.lastExecutionAt == 0 || block.timestamp >= policy.lastExecutionAt + policy.rebalanceInterval)
            && _currentDailyLoss(policy) <= policy.maxDailyLoss;
    }

    function recordExecution(address user, uint256 lossAmount) external {
        Policy storage policy = policies[user];
        require(policy.enabled && !policy.emergencyPaused, "autopilot disabled");
        if (block.timestamp >= policy.dailyWindowStartedAt + 1 days) {
            policy.dailyWindowStartedAt = block.timestamp;
            policy.dailyLossUsed = 0;
        }
        policy.dailyLossUsed += lossAmount;
        require(policy.dailyLossUsed <= policy.maxDailyLoss, "daily loss exceeded");
        policy.lastExecutionAt = block.timestamp;
        emit AutopilotExecutionRecorded(user, lossAmount, block.timestamp);
    }

    function emergencyPause() external {
        policies[msg.sender].emergencyPaused = true;
        policies[msg.sender].enabled = false;
        emit EmergencyPause(msg.sender);
    }

    function resumeAutopilot() external {
        Policy storage policy = policies[msg.sender];
        policy.emergencyPaused = false;
        policy.enabled = true;
        emit AutopilotResumed(msg.sender);
    }

    function _currentDailyLoss(Policy memory policy) private view returns (uint256) {
        if (block.timestamp >= policy.dailyWindowStartedAt + 1 days) {
            return 0;
        }
        return policy.dailyLossUsed;
    }
}
