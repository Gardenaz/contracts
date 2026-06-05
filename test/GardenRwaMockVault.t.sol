// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {AutopilotPolicy} from "../contracts/AutopilotPolicy.sol";
import {DecisionLog} from "../contracts/DecisionLog.sol";
import {GardenRwaMockVault} from "../contracts/GardenRwaMockVault.sol";
import {GardenUsdMock} from "../contracts/GardenUsdMock.sol";
import {
    MockDynamicBasketAdapter,
    MockMethStakingAdapter,
    MockUsdyLendingAdapter
} from "../contracts/MockDeFiAdapters.sol";

contract MockPriceOracle {
    int256 public answer;
    uint8 public immutable _decimals;

    constructor(int256 initialAnswer, uint8 decimals_) {
        answer = initialAnswer;
        _decimals = decimals_;
    }

    function setAnswer(int256 nextAnswer) external {
        answer = nextAnswer;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, answer, block.timestamp, block.timestamp, 1);
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }
}

contract GardenRwaMockVaultTest is Test {
    GardenRwaMockVault vault;
    GardenUsdMock usd;
    AutopilotPolicy policy;
    DecisionLog decisionLog;
    MockUsdyLendingAdapter steadyAdapter;
    MockMethStakingAdapter growthAdapter;
    MockDynamicBasketAdapter boostAdapter;
    MockPriceOracle steadyOracle;
    MockPriceOracle growthOracle;
    MockPriceOracle boostOracle;

    address user = address(0xBEEF);
    address operator = address(0xCAFE);
    address stranger = address(0xDEAD);

    bytes32 steadyStrategy = keccak256(bytes("steady"));
    bytes32 growthStrategy = keccak256(bytes("growth"));
    bytes32 boostStrategy = keccak256(bytes("boost"));

    function setUp() public {
        usd = new GardenUsdMock();
        policy = new AutopilotPolicy();
        decisionLog = new DecisionLog();
        vault = new GardenRwaMockVault(address(usd), address(policy), address(decisionLog));

        steadyOracle = new MockPriceOracle(1e8, 8);
        growthOracle = new MockPriceOracle(15e7, 8);
        boostOracle = new MockPriceOracle(2e8, 8);

        steadyAdapter = new MockUsdyLendingAdapter(address(vault), address(steadyOracle));
        growthAdapter = new MockMethStakingAdapter(address(vault), address(growthOracle));
        boostAdapter = new MockDynamicBasketAdapter(address(vault), address(boostOracle));

        usd.setMinter(address(vault), true);
        policy.setAuthorizedVault(address(vault), true);
        decisionLog.setWriter(address(vault), true);

        vault.setCropRoute(
            "steady", "Rice / Safe Harvest", "USDY", "Mantle RWA USDY Route", address(steadyAdapter), address(steadyOracle), 1, true
        );
        vault.setCropRoute(
            "growth", "Corn / Growth Field", "mETH", "Mantle mETH Yield Route", address(growthAdapter), address(growthOracle), 2, true
        );
        vault.setCropRoute(
            "boost",
            "Chili / Boost Farm",
            "USDY/mETH",
            "Mantle Dynamic RWA Route",
            address(boostAdapter),
            address(boostOracle),
            3,
            true
        );

        usd.mint(user, 10_000e18);

        address[] memory protocols = new address[](3);
        protocols[0] = address(steadyAdapter);
        protocols[1] = address(growthAdapter);
        protocols[2] = address(boostAdapter);

        address[] memory executors = new address[](1);
        executors[0] = operator;

        bytes32[] memory strategies = new bytes32[](3);
        strategies[0] = steadyStrategy;
        strategies[1] = growthStrategy;
        strategies[2] = boostStrategy;

        vm.prank(user);
        policy.setAutopilotPolicy(5_000e18, 1_000e18, 3, 1, 1 days, protocols, executors, strategies, true);

        vm.prank(user);
        vault.setVaultOperator(operator, true);
    }

    function testDepositAndWithdrawMaintainInternalCashBalance() public {
        vm.startPrank(user);
        usd.approve(address(vault), 1_000e18);
        vault.deposit(1_000e18);
        assertEq(vault.cashBalance(user), 1_000e18);
        assertEq(usd.balanceOf(address(vault)), 1_000e18);

        vault.withdraw(250e18);
        assertEq(vault.cashBalance(user), 750e18);
        assertEq(usd.balanceOf(user), 9_250e18);
        vm.stopPrank();
    }

    function testOperatorCanOpenMultiplePositionsRebalanceAndCloseWithinPolicy() public {
        vm.startPrank(user);
        usd.approve(address(vault), 2_000e18);
        vault.deposit(2_000e18);
        vm.stopPrank();

        vm.prank(operator);
        uint256 firstPositionId = vault.openPositionFor(user, "steady", 1_000e18, keccak256("decision-1"));

        vm.warp(block.timestamp + 2);

        vm.prank(operator);
        uint256 secondPositionId = vault.openPositionFor(user, "growth", 500e18, keccak256("decision-2"));

        assertEq(firstPositionId, 1);
        assertEq(secondPositionId, 2);
        assertEq(vault.cashBalance(user), 500e18);

        uint256[] memory positionIds = vault.positionIdsOf(user);
        uint256[] memory activeIds = vault.activePositionIdsOf(user);
        assertEq(positionIds.length, 2);
        assertEq(activeIds.length, 2);

        growthOracle.setAnswer(18e7);
        vm.warp(block.timestamp + 2);

        vm.prank(operator);
        uint256 nextShares = vault.rebalancePosition(firstPositionId, "growth", keccak256("decision-3"));
        assertGt(nextShares, 0);

        steadyOracle.setAnswer(11e7);
        growthOracle.setAnswer(16e7);
        vm.warp(block.timestamp + 2);

        vm.prank(operator);
        uint256 harvested = vault.closePosition(secondPositionId, keccak256("decision-4"));
        assertGt(harvested, 0);

        activeIds = vault.activePositionIdsOf(user);
        assertEq(activeIds.length, 1);

        (
            ,
            ,
            uint256 principal,
            ,
            ,
            uint256 harvestedValue,
            ,
            ,
            uint256 harvestedAt,
            bool harvestedFlag
        ) = vault.positions(secondPositionId);
        assertEq(principal, 500e18);
        assertEq(harvestedValue, harvested);
        assertTrue(harvestedFlag);
        assertEq(harvestedAt, block.timestamp);

        assertGt(vault.cashBalance(user), 500e18);
    }

    function testUnauthorizedOperatorCannotManagePosition() public {
        vm.startPrank(user);
        usd.approve(address(vault), 1_000e18);
        vault.deposit(1_000e18);
        vm.stopPrank();

        vm.prank(stranger);
        vm.expectRevert("not authorized");
        vault.openPositionFor(user, "steady", 500e18, keccak256("nope"));
    }

    function testManualUserPlantStillWorksWithoutOperatorDecisionHash() public {
        vm.startPrank(user);
        usd.approve(address(vault), 1_000e18);
        uint256 positionId = vault.plant("steady", 1_000e18);
        vm.stopPrank();

        assertEq(positionId, 1);
        assertEq(vault.cashBalance(user), 0);
        assertEq(vault.currentValue(positionId), 999e18);
    }
}
