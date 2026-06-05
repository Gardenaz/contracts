// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IPriceOracle {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function decimals() external view returns (uint8);
}

interface IMockDeFiAdapter {
    function deposit(address user, uint256 amount, bytes calldata data) external returns (uint256 shares);
    function withdraw(address user, uint256 shares, bytes calldata data) external returns (uint256 amountOut);
    function previewValue(address user, uint256 shares) external view returns (uint256 value);
    function riskLevel() external view returns (uint8);
    function priceOracle() external view returns (address);
}

abstract contract MockDeFiAdapterBase is Ownable, IMockDeFiAdapter {
    address public immutable vault;
    address public immutable override priceOracle;
    uint8 public immutable override riskLevel;
    uint256 public immutable feeBps;

    mapping(address => uint256) public userShares;
    uint256 public totalShares;

    constructor(address vault_, address oracle_, uint8 riskLevel_, uint256 feeBps_) Ownable(msg.sender) {
        require(vault_ != address(0), "bad vault");
        require(oracle_ != address(0), "bad oracle");
        require(riskLevel_ >= 1 && riskLevel_ <= 3, "bad risk");
        require(feeBps_ <= 1_000, "bad fee");
        vault = vault_;
        priceOracle = oracle_;
        riskLevel = riskLevel_;
        feeBps = feeBps_;
    }

    modifier onlyVault() {
        require(msg.sender == vault, "not vault");
        _;
    }

    function deposit(address user, uint256 amount, bytes calldata) external onlyVault returns (uint256 shares) {
        require(user != address(0), "bad user");
        require(amount > 0, "bad amount");
        uint256 price = _normalizedPrice();
        shares = (amount * 1e18) / price;
        require(shares > 0, "bad shares");
        userShares[user] += shares;
        totalShares += shares;
    }

    function withdraw(address user, uint256 shares, bytes calldata) external onlyVault returns (uint256 amountOut) {
        require(user != address(0), "bad user");
        require(shares > 0, "bad shares");
        require(userShares[user] >= shares, "insufficient shares");
        userShares[user] -= shares;
        totalShares -= shares;
        amountOut = _valueForShares(shares);
    }

    function previewValue(address, uint256 shares) external view returns (uint256 value) {
        return _valueForShares(shares);
    }

    function _valueForShares(uint256 shares) internal view returns (uint256) {
        uint256 grossValue = (shares * _normalizedPrice()) / 1e18;
        if (feeBps == 0) return grossValue;
        return grossValue - ((grossValue * feeBps) / 10_000);
    }

    function _normalizedPrice() internal view returns (uint256) {
        (, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = IPriceOracle(priceOracle).latestRoundData();
        require(answer > 0, "bad price");
        require(updatedAt != 0, "stale price");
        require(answeredInRound != 0, "bad round");

        uint8 decimals = IPriceOracle(priceOracle).decimals();
        uint256 price = uint256(answer);
        if (decimals < 18) return price * (10 ** (18 - decimals));
        if (decimals > 18) return price / (10 ** (decimals - 18));
        return price;
    }
}

contract MockUsdyLendingAdapter is MockDeFiAdapterBase {
    constructor(address vault_, address oracle_) MockDeFiAdapterBase(vault_, oracle_, 1, 10) {}
}

contract MockMethStakingAdapter is MockDeFiAdapterBase {
    constructor(address vault_, address oracle_) MockDeFiAdapterBase(vault_, oracle_, 2, 25) {}
}

contract MockDynamicBasketAdapter is MockDeFiAdapterBase {
    constructor(address vault_, address oracle_) MockDeFiAdapterBase(vault_, oracle_, 3, 50) {}
}
