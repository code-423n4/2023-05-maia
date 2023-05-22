// SPDX-License-Identifier: MIT
// Rewards logic inspired by Tribe DAO Contracts (flywheel-v2/src/FlywheelCore.sol)
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {IFlywheelBooster} from "../interfaces/IFlywheelBooster.sol";

/**
 * @title Flywheel Core Incentives Manager
 *  @author Maia DAO (https://github.com/Maia-DAO)
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
interface IFlywheelCore {
    /*///////////////////////////////////////////////////////////////
                        FLYWHEEL CORE STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The token to reward
    function rewardToken() external view returns (address);

    /// @notice append-only list of strategies added
    function allStrategies(uint256) external view returns (ERC20);

    /// @notice The strategy index in allStrategies
    function strategyIds(ERC20) external view returns (uint256);

    /// @notice the rewards contract for managing streams
    function flywheelRewards() external view returns (address);

    /// @notice optional booster module for calculating virtual balances on strategies
    function flywheelBooster() external view returns (IFlywheelBooster);

    /// @notice The accrued but not yet transferred rewards for each user
    function rewardsAccrued(address) external view returns (uint256);

    /*///////////////////////////////////////////////////////////////
                        ACCRUE/CLAIM LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice accrue rewards for a single user for msg.sender
     *   @param user the user to be accrued
     *   @return the cumulative amount of rewards accrued to user (including prior)
     */
    function accrue(address user) external returns (uint256);

    /**
     * @notice accrue rewards for a single user on a strategy
     *   @param strategy the strategy to accrue a user's rewards on
     *   @param user the user to be accrued
     *   @return the cumulative amount of rewards accrued to user (including prior)
     */
    function accrue(ERC20 strategy, address user) external returns (uint256);

    /**
     * @notice accrue rewards for a two users on a strategy
     *   @param strategy the strategy to accrue a user's rewards on
     *   @param user the first user to be accrued
     *   @param user the second user to be accrued
     *   @return the cumulative amount of rewards accrued to the first user (including prior)
     *   @return the cumulative amount of rewards accrued to the second user (including prior)
     */
    function accrue(ERC20 strategy, address user, address secondUser) external returns (uint256, uint256);

    /**
     * @notice claim rewards for a given user
     *   @param user the user claiming rewards
     *   @dev this function is public, and all rewards transfer to the user
     */
    function claimRewards(address user) external;

    /*///////////////////////////////////////////////////////////////
                          ADMIN LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice initialize a new strategy
    function addStrategyForRewards(ERC20 strategy) external;

    /// @notice Returns all strategies added to flywheel.
    function getAllStrategies() external view returns (ERC20[] memory);

    /// @notice swap out the flywheel rewards contract
    function setFlywheelRewards(address newFlywheelRewards) external;

    /// @notice swap out the flywheel booster contract
    function setBooster(IFlywheelBooster newBooster) external;

    /*///////////////////////////////////////////////////////////////
                    INTERNAL ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice The last updated index per strategy
    function strategyIndex(ERC20) external view returns (uint256);

    /// @notice The last updated index per strategy
    function userIndex(ERC20, address) external view returns (uint256);

    /*///////////////////////////////////////////////////////////////
                        EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a user's rewards accrue to a given strategy.
     *   @param strategy the updated rewards strategy
     *   @param user the user of the rewards
     *   @param rewardsDelta how many new rewards accrued to the user
     *   @param rewardsIndex the market index for rewards per token accrued
     */
    event AccrueRewards(ERC20 indexed strategy, address indexed user, uint256 rewardsDelta, uint256 rewardsIndex);

    /**
     * @notice Emitted when a user claims accrued rewards.
     *   @param user the user of the rewards
     *   @param amount the amount of rewards claimed
     */
    event ClaimRewards(address indexed user, uint256 amount);

    /**
     * @notice Emitted when a new strategy is added to flywheel by the admin
     *   @param newStrategy the new added strategy
     */
    event AddStrategy(address indexed newStrategy);

    /**
     * @notice Emitted when the rewards module changes
     *   @param newFlywheelRewards the new rewards module
     */
    event FlywheelRewardsUpdate(address indexed newFlywheelRewards);

    /**
     * @notice Emitted when the booster module changes
     *   @param newBooster the new booster module
     */
    event FlywheelBoosterUpdate(address indexed newBooster);
}
