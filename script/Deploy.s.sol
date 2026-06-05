// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {AgentIdentity} from "../contracts/AgentIdentity.sol";
import {AutopilotPolicy} from "../contracts/AutopilotPolicy.sol";
import {DecisionLog} from "../contracts/DecisionLog.sol";
import {GardenRwaMockVault} from "../contracts/GardenRwaMockVault.sol";
import {
    MockDynamicBasketAdapter,
    MockMethStakingAdapter,
    MockUsdyLendingAdapter
} from "../contracts/MockDeFiAdapters.sol";
import {GardenUsdMock} from "../contracts/GardenUsdMock.sol";
import {ReputationRegistry} from "../contracts/ReputationRegistry.sol";
import {RiskPolicy} from "../contracts/RiskPolicy.sol";
import {ValidationRegistry} from "../contracts/ValidationRegistry.sol";

contract DeployScript is Script {
    struct CoreDeployment {
        AgentIdentity agentIdentity;
        DecisionLog decisionLog;
        RiskPolicy riskPolicy;
        ReputationRegistry reputationRegistry;
        ValidationRegistry validationRegistry;
        AutopilotPolicy autopilotPolicy;
        GardenUsdMock settlementToken;
        GardenRwaMockVault vault;
    }

    struct AdapterDeployment {
        MockUsdyLendingAdapter steadyAdapter;
        MockMethStakingAdapter growthAdapter;
        MockDynamicBasketAdapter boostAdapter;
        address stableFeed;
        address growthFeed;
        address boostFeed;
    }

    function run() external {
        vm.startBroadcast();

        CoreDeployment memory core = _deployCore();
        AdapterDeployment memory adapters = _deployAdapters(core.vault);
        _configureVault(core, adapters);

        vm.stopBroadcast();

        _logDeployment(core, adapters);
    }

    function _deployCore() internal returns (CoreDeployment memory core) {
        core.agentIdentity = new AgentIdentity();
        core.decisionLog = new DecisionLog();
        core.riskPolicy = new RiskPolicy();
        core.reputationRegistry = new ReputationRegistry(address(core.agentIdentity));
        core.validationRegistry = new ValidationRegistry(address(core.agentIdentity));
        core.autopilotPolicy = new AutopilotPolicy();
        core.settlementToken = new GardenUsdMock();
        core.vault = new GardenRwaMockVault(
            address(core.settlementToken), address(core.autopilotPolicy), address(core.decisionLog)
        );
    }

    function _deployAdapters(GardenRwaMockVault vault) internal returns (AdapterDeployment memory adapters) {
        adapters.stableFeed = vm.envOr("STABLE_FEED_ADDRESS", address(0x22b422CECb0D4Bd5afF3EA999b048FA17F5263bD));
        adapters.growthFeed = vm.envOr("GROWTH_FEED_ADDRESS", address(0x5bc7Cf88EB131DB18b5d7930e793095140799aD5));
        adapters.boostFeed = vm.envOr("BOOST_FEED_ADDRESS", address(0xB16FcAFB8378baA0a69142a325878FDCad58606A));
        adapters.steadyAdapter = new MockUsdyLendingAdapter(address(vault), adapters.stableFeed);
        adapters.growthAdapter = new MockMethStakingAdapter(address(vault), adapters.growthFeed);
        adapters.boostAdapter = new MockDynamicBasketAdapter(address(vault), adapters.boostFeed);
    }

    function _configureVault(CoreDeployment memory core, AdapterDeployment memory adapters) internal {
        core.settlementToken.setMinter(address(core.vault), true);
        core.autopilotPolicy.setAuthorizedVault(address(core.vault), true);
        core.decisionLog.setWriter(address(core.vault), true);

        core.vault.setCropRoute(
            "steady",
            "Rice / Safe Harvest",
            "USDY",
            "Mantle RWA USDY Route",
            address(adapters.steadyAdapter),
            adapters.stableFeed,
            1,
            true
        );
        core.vault.setCropRoute(
            "growth",
            "Corn / Growth Field",
            "mETH",
            "Mantle mETH Yield Route",
            address(adapters.growthAdapter),
            adapters.growthFeed,
            2,
            true
        );
        core.vault.setCropRoute(
            "boost",
            "Chili / Boost Farm",
            "USDY/mETH",
            "Mantle Dynamic RWA Route",
            address(adapters.boostAdapter),
            adapters.boostFeed,
            3,
            true
        );
    }

    function _logDeployment(CoreDeployment memory core, AdapterDeployment memory adapters) internal {
        console2.log("AgentIdentity:", address(core.agentIdentity));
        console2.log("DecisionLog:", address(core.decisionLog));
        console2.log("RiskPolicy:", address(core.riskPolicy));
        console2.log("ReputationRegistry:", address(core.reputationRegistry));
        console2.log("ValidationRegistry:", address(core.validationRegistry));
        console2.log("AutopilotPolicy:", address(core.autopilotPolicy));
        console2.log("GardenUsdMock:", address(core.settlementToken));
        console2.log("GardenRwaMockVault:", address(core.vault));
        console2.log("SteadyAdapter:", address(adapters.steadyAdapter));
        console2.log("GrowthAdapter:", address(adapters.growthAdapter));
        console2.log("BoostAdapter:", address(adapters.boostAdapter));
        console2.log("StableFeed:", adapters.stableFeed);
        console2.log("GrowthFeed:", adapters.growthFeed);
        console2.log("BoostFeed:", adapters.boostFeed);
    }
}
