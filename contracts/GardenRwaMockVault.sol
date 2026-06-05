// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AutopilotPolicy} from "./AutopilotPolicy.sol";
import {DecisionLog} from "./DecisionLog.sol";
import {IMockDeFiAdapter, IPriceOracle} from "./MockDeFiAdapters.sol";

interface IGardenUsdMock is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
}

contract GardenRwaMockVault is Ownable {
    struct CropRoute {
        string name;
        string asset;
        string protocolLabel;
        address adapter;
        address oracle;
        uint8 riskLevel;
        bool active;
    }

    struct Position {
        address owner;
        bytes32 cropKeyHash;
        uint256 principal;
        uint256 assetAmount;
        uint256 plantedPrice;
        uint256 harvestedValue;
        uint256 plantedAt;
        uint256 lastRebalancedAt;
        uint256 harvestedAt;
        bool harvested;
    }

    mapping(bytes32 => CropRoute) public routes;
    mapping(uint256 => Position) public positions;
    mapping(address => mapping(address => bool)) private vaultOperators;
    mapping(address => uint256) public cashBalance;
    mapping(address => uint256[]) private userPositionIds;
    mapping(address => uint256[]) private userActivePositionIds;

    uint256 public positionCount;
    uint256 public defaultAgentId = 1;
    IGardenUsdMock public immutable settlementToken;
    AutopilotPolicy public immutable autopilotPolicy;
    DecisionLog public immutable decisionLog;

    event VaultOperatorUpdated(address indexed owner, address indexed operator, bool allowed);
    event CropRouteSet(
        bytes32 indexed cropKeyHash,
        string cropKey,
        string name,
        string asset,
        string protocolLabel,
        address adapter,
        address oracle,
        uint8 riskLevel,
        bool active
    );
    event CashDeposited(address indexed caller, address indexed user, uint256 amount);
    event CashWithdrawn(address indexed user, uint256 amount);
    event PositionPlanted(
        uint256 indexed positionId,
        address indexed owner,
        bytes32 indexed cropKeyHash,
        uint256 principal,
        uint256 assetAmount,
        uint256 plantedPrice
    );
    event PositionRebalanced(
        uint256 indexed positionId,
        bytes32 indexed fromCropKeyHash,
        bytes32 indexed toCropKeyHash,
        uint256 previousAssetAmount,
        uint256 nextAssetAmount,
        uint256 previousValue,
        uint256 nextPrice
    );
    event PositionHarvested(uint256 indexed positionId, uint256 harvestedValue, uint256 priceAtHarvest);

    constructor(address settlementToken_, address autopilotPolicy_, address decisionLog_) Ownable(msg.sender) {
        require(settlementToken_ != address(0), "bad token");
        require(autopilotPolicy_ != address(0), "bad policy");
        require(decisionLog_ != address(0), "bad log");
        settlementToken = IGardenUsdMock(settlementToken_);
        autopilotPolicy = AutopilotPolicy(autopilotPolicy_);
        decisionLog = DecisionLog(decisionLog_);
    }

    function setDefaultAgentId(uint256 agentId) external onlyOwner {
        require(agentId > 0, "bad agent");
        defaultAgentId = agentId;
    }

    function setVaultOperator(address operator, bool allowed) external {
        require(operator != address(0), "bad operator");
        vaultOperators[msg.sender][operator] = allowed;
        emit VaultOperatorUpdated(msg.sender, operator, allowed);
    }

    function isVaultOperator(address owner, address operator) external view returns (bool) {
        return vaultOperators[owner][operator];
    }

    function deposit(uint256 amount) external {
        depositFor(msg.sender, amount);
    }

    function depositFor(address user, uint256 amount) public {
        require(user != address(0), "bad user");
        require(amount > 0, "bad amount");
        require(settlementToken.transferFrom(msg.sender, address(this), amount), "payment failed");
        cashBalance[user] += amount;
        emit CashDeposited(msg.sender, user, amount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "bad amount");
        require(cashBalance[msg.sender] >= amount, "insufficient cash");
        cashBalance[msg.sender] -= amount;
        require(settlementToken.transfer(msg.sender, amount), "transfer failed");
        emit CashWithdrawn(msg.sender, amount);
    }

    function setCropRoute(
        string calldata cropKey,
        string calldata name,
        string calldata asset,
        string calldata protocolLabel,
        address adapter,
        address oracle,
        uint8 riskLevel,
        bool active
    ) external onlyOwner {
        require(bytes(cropKey).length != 0, "bad cropKey");
        require(adapter != address(0), "bad adapter");
        require(oracle != address(0), "bad oracle");
        require(riskLevel >= 1 && riskLevel <= 3, "bad risk");

        bytes32 cropKeyHash = keccak256(bytes(cropKey));
        routes[cropKeyHash] = CropRoute({
            name: name,
            asset: asset,
            protocolLabel: protocolLabel,
            adapter: adapter,
            oracle: oracle,
            riskLevel: riskLevel,
            active: active
        });
        emit CropRouteSet(cropKeyHash, cropKey, name, asset, protocolLabel, adapter, oracle, riskLevel, active);
    }

    function plant(string calldata cropKey, uint256 principal) external returns (uint256 positionId) {
        depositFor(msg.sender, principal);
        return openPositionFor(msg.sender, cropKey, principal, bytes32(0));
    }

    function openPositionFor(address user, string calldata cropKey, uint256 principal, bytes32 decisionHash)
        public
        returns (uint256 positionId)
    {
        require(principal > 0, "bad principal");
        _requireOwnerOrOperator(user);

        bytes32 cropKeyHash = keccak256(bytes(cropKey));
        CropRoute memory route = routes[cropKeyHash];
        require(route.active, "route inactive");
        require(cashBalance[user] >= principal, "insufficient cash");

        _requireFreshOracle(user, route.oracle);
        positionId = positionCount + 1;

        if (msg.sender != user) {
            require(decisionHash != bytes32(0), "decision required");
            _logDecision(positionId, user, cropKeyHash, route.adapter, principal, route.riskLevel, decisionHash);
            _recordPolicyExecution(user, route.adapter, cropKeyHash, principal, route.riskLevel, 0);
        }

        cashBalance[user] -= principal;
        settlementToken.burn(principal);

        uint256 plantedPrice = _normalizedPrice(route.oracle);
        uint256 shares = IMockDeFiAdapter(route.adapter).deposit(user, principal, "");
        require(shares > 0, "bad shares");

        positionCount = positionId;
        positions[positionId] = Position({
            owner: user,
            cropKeyHash: cropKeyHash,
            principal: principal,
            assetAmount: shares,
            plantedPrice: plantedPrice,
            harvestedValue: 0,
            plantedAt: block.timestamp,
            lastRebalancedAt: block.timestamp,
            harvestedAt: 0,
            harvested: false
        });
        userPositionIds[user].push(positionId);
        userActivePositionIds[user].push(positionId);

        emit PositionPlanted(positionId, user, cropKeyHash, principal, shares, plantedPrice);
    }

    function currentValue(uint256 positionId) public view returns (uint256) {
        Position memory position = positions[positionId];
        require(position.owner != address(0), "position not found");
        if (position.harvested) return position.harvestedValue;
        CropRoute memory route = routes[position.cropKeyHash];
        return IMockDeFiAdapter(route.adapter).previewValue(position.owner, position.assetAmount);
    }

    function previewValue(string calldata cropKey, uint256 principal) external view returns (uint256) {
        bytes32 cropKeyHash = keccak256(bytes(cropKey));
        CropRoute memory route = routes[cropKeyHash];
        require(route.active, "route inactive");
        uint256 plantedPrice = _normalizedPrice(route.oracle);
        uint256 shares = (principal * 1e18) / plantedPrice;
        return IMockDeFiAdapter(route.adapter).previewValue(address(0), shares);
    }

    function harvest(uint256 positionId) external returns (uint256 harvestedValue) {
        return closePosition(positionId, bytes32(0));
    }

    function closePosition(uint256 positionId, bytes32 decisionHash) public returns (uint256 harvestedValue) {
        Position storage position = positions[positionId];
        require(position.owner != address(0), "position not found");
        require(!position.harvested, "already harvested");
        _requireOwnerOrOperator(position.owner);

        CropRoute memory route = routes[position.cropKeyHash];
        _requireFreshOracle(position.owner, route.oracle);

        harvestedValue = IMockDeFiAdapter(route.adapter).withdraw(position.owner, position.assetAmount, "");
        uint256 priceAtHarvest = _normalizedPrice(route.oracle);
        uint256 lossAmount = harvestedValue < position.principal ? position.principal - harvestedValue : 0;

        if (msg.sender != position.owner) {
            require(decisionHash != bytes32(0), "decision required");
            _logDecision(positionId, position.owner, position.cropKeyHash, route.adapter, harvestedValue, route.riskLevel, decisionHash);
            _recordPolicyExecution(position.owner, route.adapter, position.cropKeyHash, harvestedValue, route.riskLevel, lossAmount);
        }

        settlementToken.mint(address(this), harvestedValue);
        cashBalance[position.owner] += harvestedValue;

        position.harvestedValue = harvestedValue;
        position.harvestedAt = block.timestamp;
        position.harvested = true;
        _removeActivePosition(position.owner, positionId);

        emit PositionHarvested(positionId, harvestedValue, priceAtHarvest);
    }

    function rebalance(uint256 positionId, string calldata newCropKey) external returns (uint256 nextAssetAmount) {
        return rebalancePosition(positionId, newCropKey, bytes32(0));
    }

    function rebalancePosition(uint256 positionId, string calldata newCropKey, bytes32 decisionHash)
        public
        returns (uint256 nextAssetAmount)
    {
        Position storage position = positions[positionId];
        address owner = position.owner;
        require(owner != address(0), "position not found");
        require(!position.harvested, "already harvested");
        _requireOwnerOrOperator(owner);

        bytes32 previousCropKeyHash = position.cropKeyHash;
        CropRoute memory fromRoute = routes[previousCropKeyHash];
        bytes32 toCropKeyHash = keccak256(bytes(newCropKey));
        CropRoute memory toRoute = routes[toCropKeyHash];
        require(toRoute.active, "route inactive");

        _requireFreshOracle(owner, fromRoute.oracle);
        _requireFreshOracle(owner, toRoute.oracle);

        uint256 previousShares = position.assetAmount;
        uint256 currentValueBeforeRotate = IMockDeFiAdapter(fromRoute.adapter).withdraw(owner, previousShares, "");
        uint256 nextPrice = _normalizedPrice(toRoute.oracle);
        uint256 previousPrincipal = position.principal;
        uint256 lossAmount = currentValueBeforeRotate < previousPrincipal ? previousPrincipal - currentValueBeforeRotate : 0;

        if (msg.sender != owner) {
            require(decisionHash != bytes32(0), "decision required");
            _handleDelegatedExecution(positionId, owner, toCropKeyHash, currentValueBeforeRotate, decisionHash, lossAmount);
        }

        nextAssetAmount = IMockDeFiAdapter(toRoute.adapter).deposit(owner, currentValueBeforeRotate, "");
        require(nextAssetAmount > 0, "bad rebalance size");

        position.cropKeyHash = toCropKeyHash;
        position.principal = currentValueBeforeRotate;
        position.assetAmount = nextAssetAmount;
        position.plantedPrice = nextPrice;
        position.lastRebalancedAt = block.timestamp;

        emit PositionRebalanced(
            positionId,
            previousCropKeyHash,
            toCropKeyHash,
            previousShares,
            nextAssetAmount,
            currentValueBeforeRotate,
            nextPrice
        );
    }

    function routePrice(string calldata cropKey) external view returns (uint256 price) {
        bytes32 cropKeyHash = keccak256(bytes(cropKey));
        CropRoute memory route = routes[cropKeyHash];
        require(route.active, "route inactive");
        return _normalizedPrice(route.oracle);
    }

    function positionIdsOf(address user) external view returns (uint256[] memory) {
        return userPositionIds[user];
    }

    function activePositionIdsOf(address user) external view returns (uint256[] memory) {
        return userActivePositionIds[user];
    }

    function _requireOwnerOrOperator(address owner) internal view {
        require(msg.sender == owner || vaultOperators[owner][msg.sender], "not authorized");
    }

    function _logDecision(
        uint256 positionId,
        address user,
        bytes32 strategyId,
        address targetProtocol,
        uint256 amount,
        uint8 riskLevel,
        bytes32 decisionHash
    ) internal {
        decisionLog.logDecision(
            defaultAgentId,
            decisionHash,
            strategyId,
            targetProtocol,
            amount,
            riskLevel,
            user,
            positionId,
            autopilotPolicy.policyVersion(user),
            msg.sender
        );
    }

    function _recordPolicyExecution(
        address user,
        address protocol,
        bytes32 strategyId,
        uint256 amount,
        uint8 riskLevel,
        uint256 lossAmount
    ) internal {
        autopilotPolicy.recordExecution(user, msg.sender, protocol, strategyId, amount, riskLevel, lossAmount);
    }

    function _handleDelegatedExecution(
        uint256 positionId,
        address user,
        bytes32 strategyId,
        uint256 amount,
        bytes32 decisionHash,
        uint256 lossAmount
    ) internal {
        CropRoute memory route = routes[strategyId];
        _logDecision(positionId, user, strategyId, route.adapter, amount, route.riskLevel, decisionHash);
        _recordPolicyExecution(user, route.adapter, strategyId, amount, route.riskLevel, lossAmount);
    }

    function _removeActivePosition(address user, uint256 positionId) internal {
        uint256[] storage activeIds = userActivePositionIds[user];
        for (uint256 i = 0; i < activeIds.length; i++) {
            if (activeIds[i] == positionId) {
                activeIds[i] = activeIds[activeIds.length - 1];
                activeIds.pop();
                return;
            }
        }
    }

    function _requireFreshOracle(address user, address oracle) internal view {
        (, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = IPriceOracle(oracle).latestRoundData();
        require(answer > 0, "bad price");
        require(updatedAt != 0, "stale price");
        require(answeredInRound != 0, "bad round");
        (, , , , uint256 heartbeat, , , , , ) = autopilotPolicy.policies(user);
        require(heartbeat > 0, "policy heartbeat missing");
        require(block.timestamp <= updatedAt + heartbeat, "oracle heartbeat exceeded");
    }

    function _normalizedPrice(address oracle) internal view returns (uint256) {
        (, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = IPriceOracle(oracle).latestRoundData();
        require(answer > 0, "bad price");
        require(updatedAt != 0, "stale price");
        require(answeredInRound != 0, "bad round");

        uint8 decimals = IPriceOracle(oracle).decimals();
        uint256 price = uint256(answer);
        if (decimals < 18) {
            return price * (10 ** (18 - decimals));
        }
        if (decimals > 18) {
            return price / (10 ** (decimals - 18));
        }
        return price;
    }
}
