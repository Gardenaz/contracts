// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract GardenStrategyAssetMock is ERC20, Ownable {
    mapping(address => bool) public minters;

    event MinterUpdated(address indexed minter, bool allowed);

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) Ownable(msg.sender) {
        minters[msg.sender] = true;
    }

    modifier onlyMinter() {
        require(minters[msg.sender], "not minter");
        _;
    }

    function setMinter(address minter, bool allowed) external onlyOwner {
        require(minter != address(0), "bad minter");
        minters[minter] = allowed;
        emit MinterUpdated(minter, allowed);
    }

    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyMinter {
        _burn(from, amount);
    }
}
