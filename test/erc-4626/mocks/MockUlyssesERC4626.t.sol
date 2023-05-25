// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {UlyssesERC4626} from "@ERC4626/UlyssesERC4626.sol";

contract MockUlyssesERC4626 is UlyssesERC4626 {
    uint256 public beforeWithdrawHookCalledCounter = 0;
    uint256 public afterDepositHookCalledCounter = 0;

    using SafeTransferLib for address;

    constructor(address _underlying, string memory _name, string memory _symbol)
        UlyssesERC4626(_underlying, _name, _symbol)
    {}

    function totalAssets() public view override returns (uint256) {
        return totalSupply;
    }

    function beforeDeposit(uint256 assets) internal override returns (uint256) {
        afterDepositHookCalledCounter++;
        return assets;
    }

    function beforeMint(uint256 shares) internal override returns (uint256) {
        afterDepositHookCalledCounter++;
        return shares;
    }

    function afterRedeem(uint256 shares) internal override returns (uint256) {
        beforeWithdrawHookCalledCounter++;
        return shares;
    }
}
