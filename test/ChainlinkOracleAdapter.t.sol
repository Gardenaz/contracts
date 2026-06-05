// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ChainlinkCrossRateOracle} from "../contracts/oracles/ChainlinkCrossRateOracle.sol";
import {ChainlinkOracleAdapter} from "../contracts/oracles/ChainlinkOracleAdapter.sol";

contract MockChainlinkFeed {
    int256 public answer;
    uint8 public immutable _decimals;
    string public feedDescription;
    uint256 public feedVersion = 1;
    uint256 public updatedAt;

    constructor(int256 initialAnswer, uint8 decimals_, string memory description_) {
        answer = initialAnswer;
        _decimals = decimals_;
        feedDescription = description_;
        updatedAt = block.timestamp;
    }

    function setAnswer(int256 nextAnswer) external {
        answer = nextAnswer;
        updatedAt = block.timestamp;
    }

    function setUpdatedAt(uint256 nextUpdatedAt) external {
        updatedAt = nextUpdatedAt;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function description() external view returns (string memory) {
        return feedDescription;
    }

    function version() external view returns (uint256) {
        return feedVersion;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256, uint256 startedAt, uint256 updatedAt_, uint80 answeredInRound)
    {
        return (1, answer, updatedAt, updatedAt, 1);
    }
}

contract ChainlinkOracleAdapterTest is Test {
    function testAdapterPassesThroughPriceAndMetadata() public {
        MockChainlinkFeed feed = new MockChainlinkFeed(1_00000000, 8, "USDY/USD");
        ChainlinkOracleAdapter adapter = new ChainlinkOracleAdapter(address(feed), 3_600);

        (, int256 answer,, uint256 updatedAt,) = adapter.latestRoundData();

        assertEq(answer, 1_00000000);
        assertEq(updatedAt, block.timestamp);
        assertEq(adapter.decimals(), 8);
        assertEq(adapter.description(), "USDY/USD");
    }

    function testAdapterRevertsWhenPriceStale() public {
        MockChainlinkFeed feed = new MockChainlinkFeed(1_00000000, 8, "USDY/USD");
        ChainlinkOracleAdapter adapter = new ChainlinkOracleAdapter(address(feed), 1);

        vm.warp(block.timestamp + 2);

        vm.expectRevert(ChainlinkOracleAdapter.StalePrice.selector);
        adapter.latestRoundData();
    }

    function testCrossRateComputesUsdYOverMEth() public {
        MockChainlinkFeed usdy = new MockChainlinkFeed(1_02000000, 8, "USDY/USD");
        MockChainlinkFeed meth = new MockChainlinkFeed(3_20000000, 8, "mETH/USD");
        ChainlinkCrossRateOracle oracle = new ChainlinkCrossRateOracle(address(usdy), address(meth), 3_600);

        (, int256 answer,, uint256 updatedAt,) = oracle.latestRoundData();

        assertEq(updatedAt, block.timestamp);
        assertEq(uint256(answer), 318750000000000000);
        assertEq(oracle.decimals(), 18);
    }
}

