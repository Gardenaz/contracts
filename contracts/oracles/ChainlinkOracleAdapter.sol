// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IChainlinkAggregatorV3 {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

contract ChainlinkOracleAdapter is Ownable {
    IChainlinkAggregatorV3 public feed;
    uint256 public maxStaleness;

    error BadFeed();
    error BadStaleness();
    error BadPrice();
    error StalePrice();

    constructor(address feed_, uint256 maxStaleness_) Ownable(msg.sender) {
        _setFeed(feed_);
        _setMaxStaleness(maxStaleness_);
    }

    function setFeed(address feed_) external onlyOwner {
        _setFeed(feed_);
    }

    function setMaxStaleness(uint256 maxStaleness_) external onlyOwner {
        _setMaxStaleness(maxStaleness_);
    }

    function decimals() external view returns (uint8) {
        return feed.decimals();
    }

    function description() external view returns (string memory) {
        return feed.description();
    }

    function version() external view returns (uint256) {
        return feed.version();
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = feed.latestRoundData();
        if (answer <= 0) revert BadPrice();
        if (updatedAt == 0) revert StalePrice();
        if (maxStaleness != 0 && block.timestamp - updatedAt > maxStaleness) revert StalePrice();
    }

    function _setFeed(address feed_) internal {
        if (feed_ == address(0)) revert BadFeed();
        feed = IChainlinkAggregatorV3(feed_);
    }

    function _setMaxStaleness(uint256 maxStaleness_) internal {
        if (maxStaleness_ == 0) revert BadStaleness();
        maxStaleness = maxStaleness_;
    }
}

