// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {ERC4626DepositOnly} from "@ERC4626/ERC4626DepositOnly.sol";

contract MockERC4626DepositOnly is ERC4626DepositOnly {
    uint256 public beforeWithdrawHookCalledCounter = 0;
    uint256 public afterDepositHookCalledCounter = 0;

    constructor(ERC20 _underlying, string memory _name, string memory _symbol)
        ERC4626DepositOnly(_underlying, _name, _symbol)
    {}

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function afterDeposit(uint256, uint256) internal override {
        afterDepositHookCalledCounter++;
    }
}
