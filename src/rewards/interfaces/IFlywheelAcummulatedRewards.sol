// SPDX-License-Identifier: MIT
// Rewards logic inspired by Tribe DAO Contracts (flywheel-v2/src/rewards/FlywheelDynamicRewards.sol)
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

/**
 * @title Flywheel Accumulated Rewards.
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice This contract is responsible for strategy rewards management.
 *          Once every cycle all the rewards can be accrued from the strategy's corresponding rewards depot for subsequent distribution.
 *          The reward depot serves as a pool of rewards.
 *          The getNextCycleRewards() hook should also transfer the next cycle's rewards to this contract to ensure proper accounting.
 */
interface IFlywheelAcummulatedRewards {
    /*//////////////////////////////////////////////////////////////
                        REWARDS CONTRACT STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice the length of a rewards cycle
    function rewardsCycleLength() external view returns (uint256);

    /// @notice end of current active rewards cycle's UNIX timestamp.
    function endCycle() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                        FLYWHEEL CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice calculate and transfer accrued rewards to flywheel core
     *  @param strategy the strategy to accrue rewards for
     *  @return amount amounts of tokens accrued and transferred
     */
    function getAccruedRewards(ERC20 strategy) external returns (uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice emitted every time a new rewards cycle begins
    event NewRewardsCycle(uint32 indexed start, uint256 indexed end, uint256 reward);
}
