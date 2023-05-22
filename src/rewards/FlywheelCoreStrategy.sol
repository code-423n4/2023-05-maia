// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {FlywheelCore as Core} from "./base/FlywheelCore.sol";

import {IFlywheelBooster} from "./interfaces/IFlywheelBooster.sol";
import {IFlywheelAcummulatedRewards} from "./interfaces/IFlywheelAcummulatedRewards.sol";
import {IFlywheelRewards} from "./interfaces/IFlywheelRewards.sol";

/**
 * @title Flywheel Core Incentives Manager
 *  @notice Flywheel is a general framework for managing token incentives.
 *          It takes reward streams to various *strategies* such as staking LP tokens and divides them among *users* of those strategies.
 *
 *          The Core contract maintains three important pieces of state:
 * the rewards index which determines how many rewards are owed per token per strategy. User indexes track how far behind the strategy they are to lazily calculate all catch-up rewards.
 * the accrued (unclaimed) rewards per user.
 * references to the booster and rewards module described below.
 *
 *          Core does not manage any tokens directly. The rewards module maintains token balances, and approves core to pull transfer them to users when they claim.
 *
 *          SECURITY NOTE: For maximum accuracy and to avoid exploits, rewards accrual should be notified atomically through the accrue hook.
 *          Accrue should be called any time tokens are transferred, minted, or burned.
 */
contract FlywheelCore is Core {
    constructor(
        address _rewardToken,
        IFlywheelRewards _flywheelRewards,
        IFlywheelBooster _flywheelBooster,
        address _owner
    ) Core(_rewardToken, address(_flywheelRewards), _flywheelBooster, _owner) {}

    function _getAccruedRewards(ERC20 strategy) internal override returns (uint256) {
        return IFlywheelAcummulatedRewards(flywheelRewards).getAccruedRewards(strategy);
    }
}
