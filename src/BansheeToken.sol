// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title BansheeToken
/// @notice ERC-20 reward token minted to artists as Proof-of-Performance rewards.
contract BansheeToken is ERC20, AccessControl {
    bytes32 public constant REWARD_MINTER_ROLE = keccak256("REWARD_MINTER_ROLE");

    constructor(address admin) ERC20("Banshee", "BANSHEE") {
        require(admin != address(0), "admin=0");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function mintPerformanceReward(address artist, uint256 amount)
        external
        onlyRole(REWARD_MINTER_ROLE)
    {
        require(artist != address(0), "artist=0");
        require(amount > 0, "amount=0");
        _mint(artist, amount);
    }
}
