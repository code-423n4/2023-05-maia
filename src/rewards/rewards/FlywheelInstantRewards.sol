// SPDX-License-Identifier: MIT
// Rewards logic inspired by Tribe DAO Contracts (flywheel-v2/src/rewards/FlywheelDynamicRewards.sol)
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {BaseFlywheelRewards, FlywheelCore} from "../base/BaseFlywheelRewards.sol";
import {SingleRewardsDepot} from "../depots/SingleRewardsDepot.sol";

import {IFlywheelInstantRewards} from "../interfaces/IFlywheelInstantRewards.sol";

/// @title Flywheel Instant Rewards.
contract FlywheelInstantRewards is BaseFlywheelRewards, IFlywheelInstantRewards {
    using SafeTransferLib for ERC20;
    using SafeCastLib for uint256;

    /// @notice RewardsDepot for this contract, shared between all strategy
    SingleRewardsDepot public immutable rewardsDepot;

    /**
     * @notice Flywheel Instant Rewards constructor.
     *  @param _flywheel flywheel core contract
     */
    constructor(FlywheelCore _flywheel) BaseFlywheelRewards(_flywheel) {
        rewardsDepot = new SingleRewardsDepot(rewardToken);
    }

    /// @inheritdoc IFlywheelInstantRewards
    function getAccruedRewards() external override onlyFlywheel returns (uint256) {
        return rewardsDepot.getRewards(); // get exisiting rewards
    }
}
