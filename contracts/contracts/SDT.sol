// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Smart Deal Token (SDT)
/// @notice Fixed-supply ERC-20 for marketplace listing fees and seller stake.
/// @dev Demo mint only: the entire supply is minted once in the constructor to
///      `initialHolder`. There is no Ownable mint afterwards — no admin can
///      inflate supply after deploy.
contract SDT is ERC20 {
    /// @param initialHolder Receives the full fixed demo supply (typically the deployer).
    /// @param initialSupply Fixed total supply in wei units (18 decimals), e.g. 10_000_000e18.
    constructor(address initialHolder, uint256 initialSupply) ERC20("Smart Deal Token", "SDT") {
        require(initialHolder != address(0), "SDT: zero holder");
        require(initialSupply > 0, "SDT: zero supply");
        _mint(initialHolder, initialSupply);
    }
}
