// SPDX-License-Identifier: MIT
// Rewards logic inspired by Tribe DAO Contracts (flywheel-v2/src/rewards/FlywheelDynamicRewards.sol)
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {FlywheelCore} from "../base/FlywheelCore.sol";
import {RewardsDepot} from "../depots/RewardsDepot.sol";
import {FlywheelAcummulatedRewards} from "../rewards/FlywheelAcummulatedRewards.sol";

import {IFlywheelBribeRewards} from "../interfaces/IFlywheelBribeRewards.sol";

/// @title Flywheel Accumulated Bribes Reward Stream
contract FlywheelBribeRewards is FlywheelAcummulatedRewards, IFlywheelBribeRewards {
    /*//////////////////////////////////////////////////////////////
                        REWARDS CONTRACT STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFlywheelBribeRewards
    mapping(ERC20 => RewardsDepot) public override rewardsDepots;

    /**
     * @notice Flywheel Accumulated Bribes Reward Stream constructor.
     *  @param _flywheel flywheel core contract
     *  @param _rewardsCycleLength the length of a rewards cycle in seconds
     */
    constructor(FlywheelCore _flywheel, uint256 _rewardsCycleLength)
        FlywheelAcummulatedRewards(_flywheel, _rewardsCycleLength)
    {}

    /// @notice calculate and transfer accrued rewards to flywheel core
    function getNextCycleRewards(ERC20 strategy) internal override returns (uint256) {
        return rewardsDepots[strategy].getRewards();
    }

    /// @inheritdoc IFlywheelBribeRewards
    function setRewardsDepot(RewardsDepot rewardsDepot) external {
        /// @dev Anyone can call this, whitelisting is handled in FlywheelCore
        rewardsDepots[ERC20(msg.sender)] = rewardsDepot;

        emit AddRewardsDepot(msg.sender, rewardsDepot);
    }
}
