// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract AutopilotPolicy is Ownable {
    struct Policy {
        uint256 maxTxAmount;
        uint256 maxDailyLoss;
        uint8 maxRiskLevel;
        uint256 rebalanceInterval;
        uint256 oracleHeartbeat;
        bool enabled;
        bool emergencyPaused;
        uint256 lastExecutionAt;
        uint256 dailyLossUsed;
        uint256 dailyWindowStartedAt;
    }

    mapping(address => Policy) public policies;
    mapping(address => uint256) public policyVersion;
    mapping(address => mapping(address => bool)) public allowedProtocols;
    mapping(address => mapping(address => bool)) public allowedExecutors;
    mapping(address => mapping(bytes32 => bool)) public allowedStrategies;
    mapping(address => address[]) private protocolLists;
    mapping(address => address[]) private executorLists;
    mapping(address => bytes32[]) private strategyLists;
    mapping(address => bool) public authorizedVaults;

    event AutopilotPolicySet(
        address indexed user,
        uint256 maxTxAmount,
        uint256 maxDailyLoss,
        uint8 maxRiskLevel,
        uint256 rebalanceInterval,
        uint256 oracleHeartbeat,
        uint256 policyVersion,
        bool enabled
    );
    event ProtocolAllowed(address indexed user, address indexed protocol, bool allowed);
    event ExecutorAllowed(address indexed user, address indexed executor, bool allowed);
    event StrategyAllowed(address indexed user, bytes32 indexed strategyId, bool allowed);
    event VaultAuthorized(address indexed vault, bool allowed);
    event AutopilotExecutionRecorded(
        address indexed user,
        address indexed executor,
        address indexed protocol,
        bytes32 strategyId,
        uint256 amount,
        uint256 lossAmount,
        uint256 timestamp
    );
    event EmergencyPause(address indexed user);
    event AutopilotResumed(address indexed user);

    constructor() Ownable(msg.sender) {}

    modifier onlyAuthorizedVault() {
        require(authorizedVaults[msg.sender], "not vault");
        _;
    }

    function setAuthorizedVault(address vault, bool allowed) external onlyOwner {
        require(vault != address(0), "bad vault");
        authorizedVaults[vault] = allowed;
        emit VaultAuthorized(vault, allowed);
    }

    function setAutopilotPolicy(
        uint256 maxTxAmount,
        uint256 maxDailyLoss,
        uint8 maxRiskLevel,
        uint256 rebalanceInterval,
        uint256 oracleHeartbeat,
        address[] calldata protocols,
        address[] calldata executors,
        bytes32[] calldata strategies,
        bool enabled
    ) external {
        require(maxRiskLevel >= 1 && maxRiskLevel <= 3, "bad risk");
        require(rebalanceInterval > 0, "bad interval");
        require(oracleHeartbeat > 0, "bad heartbeat");

        Policy storage policy = policies[msg.sender];
        policy.maxTxAmount = maxTxAmount;
        policy.maxDailyLoss = maxDailyLoss;
        policy.maxRiskLevel = maxRiskLevel;
        policy.rebalanceInterval = rebalanceInterval;
        policy.oracleHeartbeat = oracleHeartbeat;
        policy.enabled = enabled;
        policy.emergencyPaused = false;
        if (policy.dailyWindowStartedAt == 0) {
            policy.dailyWindowStartedAt = block.timestamp;
        }

        _replaceProtocols(msg.sender, protocols);
        _replaceExecutors(msg.sender, executors);
        _replaceStrategies(msg.sender, strategies);

        uint256 version = ++policyVersion[msg.sender];
        emit AutopilotPolicySet(
            msg.sender, maxTxAmount, maxDailyLoss, maxRiskLevel, rebalanceInterval, oracleHeartbeat, version, enabled
        );
    }

    function setProtocolAllowed(address protocol, bool allowed) external {
        require(protocol != address(0), "bad protocol");
        if (allowed && !allowedProtocols[msg.sender][protocol]) {
            protocolLists[msg.sender].push(protocol);
        }
        allowedProtocols[msg.sender][protocol] = allowed;
        emit ProtocolAllowed(msg.sender, protocol, allowed);
    }

    function setExecutorAllowed(address executor, bool allowed) external {
        require(executor != address(0), "bad executor");
        if (allowed && !allowedExecutors[msg.sender][executor]) {
            executorLists[msg.sender].push(executor);
        }
        allowedExecutors[msg.sender][executor] = allowed;
        emit ExecutorAllowed(msg.sender, executor, allowed);
    }

    function setStrategyAllowed(bytes32 strategyId, bool allowed) external {
        require(strategyId != bytes32(0), "bad strategy");
        if (allowed && !allowedStrategies[msg.sender][strategyId]) {
            strategyLists[msg.sender].push(strategyId);
        }
        allowedStrategies[msg.sender][strategyId] = allowed;
        emit StrategyAllowed(msg.sender, strategyId, allowed);
    }

    function canExecute(
        address user,
        address executor,
        address protocol,
        bytes32 strategyId,
        uint256 amount,
        uint8 riskLevel
    ) public view returns (bool) {
        Policy memory policy = policies[user];
        bool strategyAllowed = strategyLists[user].length == 0 || allowedStrategies[user][strategyId];
        return policy.enabled && !policy.emergencyPaused && amount <= policy.maxTxAmount && riskLevel <= policy.maxRiskLevel
            && allowedProtocols[user][protocol] && allowedExecutors[user][executor] && strategyAllowed
            && (policy.lastExecutionAt == 0 || block.timestamp >= policy.lastExecutionAt + policy.rebalanceInterval)
            && _currentDailyLoss(policy) <= policy.maxDailyLoss;
    }

    function recordExecution(
        address user,
        address executor,
        address protocol,
        bytes32 strategyId,
        uint256 amount,
        uint8 riskLevel,
        uint256 lossAmount
    ) external onlyAuthorizedVault {
        require(canExecute(user, executor, protocol, strategyId, amount, riskLevel), "policy blocked");
        Policy storage policy = policies[user];
        if (block.timestamp >= policy.dailyWindowStartedAt + 1 days) {
            policy.dailyWindowStartedAt = block.timestamp;
            policy.dailyLossUsed = 0;
        }
        policy.dailyLossUsed += lossAmount;
        require(policy.dailyLossUsed <= policy.maxDailyLoss, "daily loss exceeded");
        policy.lastExecutionAt = block.timestamp;
        emit AutopilotExecutionRecorded(user, executor, protocol, strategyId, amount, lossAmount, block.timestamp);
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

    function protocolListOf(address user) external view returns (address[] memory) {
        return protocolLists[user];
    }

    function executorListOf(address user) external view returns (address[] memory) {
        return executorLists[user];
    }

    function strategyListOf(address user) external view returns (bytes32[] memory) {
        return strategyLists[user];
    }

    function _replaceProtocols(address user, address[] calldata protocols) private {
        address[] storage current = protocolLists[user];
        for (uint256 i = 0; i < current.length; i++) {
            address protocol = current[i];
            if (allowedProtocols[user][protocol]) {
                allowedProtocols[user][protocol] = false;
                emit ProtocolAllowed(user, protocol, false);
            }
        }
        delete protocolLists[user];

        for (uint256 i = 0; i < protocols.length; i++) {
            require(protocols[i] != address(0), "bad protocol");
            allowedProtocols[user][protocols[i]] = true;
            protocolLists[user].push(protocols[i]);
            emit ProtocolAllowed(user, protocols[i], true);
        }
    }

    function _replaceExecutors(address user, address[] calldata executors) private {
        address[] storage current = executorLists[user];
        for (uint256 i = 0; i < current.length; i++) {
            address executor = current[i];
            if (allowedExecutors[user][executor]) {
                allowedExecutors[user][executor] = false;
                emit ExecutorAllowed(user, executor, false);
            }
        }
        delete executorLists[user];

        for (uint256 i = 0; i < executors.length; i++) {
            require(executors[i] != address(0), "bad executor");
            allowedExecutors[user][executors[i]] = true;
            executorLists[user].push(executors[i]);
            emit ExecutorAllowed(user, executors[i], true);
        }
    }

    function _replaceStrategies(address user, bytes32[] calldata strategies) private {
        bytes32[] storage current = strategyLists[user];
        for (uint256 i = 0; i < current.length; i++) {
            bytes32 strategyId = current[i];
            if (allowedStrategies[user][strategyId]) {
                allowedStrategies[user][strategyId] = false;
                emit StrategyAllowed(user, strategyId, false);
            }
        }
        delete strategyLists[user];

        for (uint256 i = 0; i < strategies.length; i++) {
            require(strategies[i] != bytes32(0), "bad strategy");
            allowedStrategies[user][strategies[i]] = true;
            strategyLists[user].push(strategies[i]);
            emit StrategyAllowed(user, strategies[i], true);
        }
    }

    function _currentDailyLoss(Policy memory policy) private view returns (uint256) {
        if (block.timestamp >= policy.dailyWindowStartedAt + 1 days) {
            return 0;
        }
        return policy.dailyLossUsed;
    }
}
