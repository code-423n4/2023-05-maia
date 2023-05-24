// SPDX-License-Identifier: MIT
// Rewards logic inspired by Tribe DAO Contracts (flywheel-v2/src/rewards/FlywheelDynamicRewards.sol)
pragma solidity ^0.8.0;

/**
 *  @title Flywheel Instant Rewards.
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice This contract is responsible for strategy rewards management.
 *          At any moment all the rewards can be accrued from any strategy
 *          from the general rewards depot for subsequent distribution.
 *          The reward depot serves as a pool of rewards.
 */
interface IFlywheelInstantRewards {
    /**
     * @notice calculate rewards amount accrued to a strategy since the last update.
     *  @return rewards the amounts of rewards accrued to the market
     *  @dev MUST be called as soon as rewards are deposited into the rewards depot.
     */
    function getAccruedRewards() external returns (uint256 rewards);
}
