// SPDX-License-Identifier: MIT
// Rewards logic inspired by Tribe DAO Contracts (flywheel-v2/src/rewards/BaseFlywheelRewards.sol)
pragma solidity ^0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {FlywheelCore} from "./FlywheelCore.sol";

import {IFlywheelRewards} from "../interfaces/IFlywheelRewards.sol";

/**
 * @title Flywheel Reward Module - Base contract for reward token distribution
 *  @notice Determines how many rewards accrue to each strategy globally over a given time period.
 *  @dev approves the flywheel core for the reward token to allow balances to be managed by the module but claimed from core.
 */
abstract contract BaseFlywheelRewards is IFlywheelRewards {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                        REWARDS CONTRACT STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFlywheelRewards
    address public immutable override rewardToken;

    /// @inheritdoc IFlywheelRewards
    FlywheelCore public immutable override flywheel;

    constructor(FlywheelCore _flywheel) {
        flywheel = _flywheel;
        address _rewardToken = _flywheel.rewardToken();
        rewardToken = _rewardToken;

        _rewardToken.safeApprove(address(_flywheel), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyFlywheel() {
        if (msg.sender != address(flywheel)) revert FlywheelError();
        _;
    }
}
