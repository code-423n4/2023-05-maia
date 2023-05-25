// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {IBaseVault} from "@maia/interfaces/IBaseVault.sol";

contract MockVault is IBaseVault {
    function applyWeight() external override {}

    function applyBoost() external override {}

    function applyGovernance() external override {}

    function applyAll() external override {}

    function clearWeight(uint256) external override {}

    function clearBoost(uint256) external override {}

    function clearGovernance(uint256) external override {}

    function clearAll() external override {}
}
