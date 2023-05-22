// SPDX-License-Identifier: MIT
// Rewards logic inspired by Tribe DAO Contracts (flywheel-v2/src/rewards/FlywheelDynamicRewards.sol)
pragma solidity ^0.8.0;

import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {BaseFlywheelRewards, FlywheelCore} from "../base/BaseFlywheelRewards.sol";

import {IFlywheelAcummulatedRewards} from "../interfaces/IFlywheelAcummulatedRewards.sol";

///  @title Flywheel Accumulated Rewards.
abstract contract FlywheelAcummulatedRewards is BaseFlywheelRewards, IFlywheelAcummulatedRewards {
    using SafeCastLib for uint256;

    /*//////////////////////////////////////////////////////////////
                        REWARDS CONTRACT STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFlywheelAcummulatedRewards
    uint256 public immutable override rewardsCycleLength;

    /// @inheritdoc IFlywheelAcummulatedRewards
    uint256 public override endCycle;

    /**
     * @notice Flywheel Instant Rewards constructor.
     *  @param _flywheel flywheel core contract
     *  @param _rewardsCycleLength the length of a rewards cycle in seconds
     */
    constructor(FlywheelCore _flywheel, uint256 _rewardsCycleLength) BaseFlywheelRewards(_flywheel) {
        rewardsCycleLength = _rewardsCycleLength;
    }

    /*//////////////////////////////////////////////////////////////
                        FLYWHEEL CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFlywheelAcummulatedRewards
    function getAccruedRewards(ERC20 strategy) external override onlyFlywheel returns (uint256 amount) {
        uint32 timestamp = block.timestamp.toUint32();

        // if cycle has ended, reset cycle and transfer all available
        if (timestamp >= endCycle) {
            amount = getNextCycleRewards(strategy);

            // reset for next cycle
            uint256 newEndCycle = ((timestamp + rewardsCycleLength) / rewardsCycleLength) * rewardsCycleLength;
            endCycle = newEndCycle;

            emit NewRewardsCycle(timestamp, newEndCycle, amount);
        } else {
            amount = 0;
        }
    }

    /// @notice function to get the next cycle's rewards amount
    function getNextCycleRewards(ERC20 strategy) internal virtual returns (uint256);
}
