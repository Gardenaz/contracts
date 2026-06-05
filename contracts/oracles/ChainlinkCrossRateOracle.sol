// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IChainlinkAggregatorV3} from "./ChainlinkOracleAdapter.sol";

contract ChainlinkCrossRateOracle is Ownable {
    IChainlinkAggregatorV3 public baseFeed;
    IChainlinkAggregatorV3 public quoteFeed;
    uint256 public maxStaleness;

    error BadFeed();
    error BadStaleness();
    error BadPrice();
    error StalePrice();

    constructor(address baseFeed_, address quoteFeed_, uint256 maxStaleness_) Ownable(msg.sender) {
        _setBaseFeed(baseFeed_);
        _setQuoteFeed(quoteFeed_);
        _setMaxStaleness(maxStaleness_);
    }

    function setBaseFeed(address baseFeed_) external onlyOwner {
        _setBaseFeed(baseFeed_);
    }

    function setQuoteFeed(address quoteFeed_) external onlyOwner {
        _setQuoteFeed(quoteFeed_);
    }

    function setMaxStaleness(uint256 maxStaleness_) external onlyOwner {
        _setMaxStaleness(maxStaleness_);
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function description() external pure returns (string memory) {
        return "Chainlink cross rate oracle";
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (, int256 baseAnswer,, uint256 baseUpdatedAt,) = baseFeed.latestRoundData();
        (, int256 quoteAnswer,, uint256 quoteUpdatedAt,) = quoteFeed.latestRoundData();

        if (baseAnswer <= 0 || quoteAnswer <= 0) revert BadPrice();
        if (baseUpdatedAt == 0 || quoteUpdatedAt == 0) revert StalePrice();
        if (maxStaleness != 0) {
            if (block.timestamp - baseUpdatedAt > maxStaleness) revert StalePrice();
            if (block.timestamp - quoteUpdatedAt > maxStaleness) revert StalePrice();
        }

        uint256 normalizedBase = _normalize(baseFeed, baseAnswer);
        uint256 normalizedQuote = _normalize(quoteFeed, quoteAnswer);
        uint256 normalizedAnswer = (normalizedBase * 1e18) / normalizedQuote;

        roundId = 1;
        answer = int256(normalizedAnswer);
        startedAt = baseUpdatedAt < quoteUpdatedAt ? baseUpdatedAt : quoteUpdatedAt;
        updatedAt = startedAt;
        answeredInRound = 1;
    }

    function _setBaseFeed(address baseFeed_) internal {
        if (baseFeed_ == address(0)) revert BadFeed();
        baseFeed = IChainlinkAggregatorV3(baseFeed_);
    }

    function _setQuoteFeed(address quoteFeed_) internal {
        if (quoteFeed_ == address(0)) revert BadFeed();
        quoteFeed = IChainlinkAggregatorV3(quoteFeed_);
    }

    function _setMaxStaleness(uint256 maxStaleness_) internal {
        if (maxStaleness_ == 0) revert BadStaleness();
        maxStaleness = maxStaleness_;
    }

    function _normalize(IChainlinkAggregatorV3 feed, int256 answer) internal view returns (uint256) {
        uint8 feedDecimals = feed.decimals();
        uint256 price = uint256(answer);
        if (feedDecimals < 18) {
            return price * (10 ** (18 - feedDecimals));
        }
        if (feedDecimals > 18) {
            return price / (10 ** (feedDecimals - 18));
        }
        return price;
    }
}
