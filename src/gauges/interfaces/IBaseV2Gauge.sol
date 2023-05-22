// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FlywheelCore} from "@rewards/FlywheelCoreStrategy.sol";
import {FlywheelGaugeRewards} from "@rewards/rewards/FlywheelGaugeRewards.sol";
import {MultiRewardsDepot} from "@rewards/depots/MultiRewardsDepot.sol";

/**
 * @title Base V2 Gauge
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice Handles rewards for distribution, boost attaching/detaching and
 *          accruing bribes for a given strategy.
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡤⠒⠈⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠐⢤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠑⠦⣄⠀⠀⢀⣠⠖⢶⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠞⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠑⢤⡈⠳⣦⡀⠀⠀⠀⠀⠀⠀⠒⢦⣀⠀⠀⠈⢱⠖⠉⠀⠀⠀⠳⡄⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠞⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠳⣌⣻⣦⡀⠀⠀⠀⠀⠀⠀⠈⠳⢄⢠⡏⠀⠀⠐⠀⠀⠀⠘⡀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⣠⠞⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⠀⠙⢿⣿⣄⠈⠓⢄⠀⠀⠀⠀⠈⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⢀⡴⠁⠀⠀⠀⡠⠂⠀⠀⠀⡾⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢦⠀⠀⠀⠀⠀⠑⢄⠀⠀⠙⢿⣦⠀⠀⠑⢄⠀⠀⢰⠃⠀⠀⠀⠀⢀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⢠⠞⠀⠀⠀⠀⢰⠃⠀⠀⠀⠀⠧⠀⠀⠀⠀⠀⡄⠀⠀⠀⠀⠀⠈⢧⠀⠀⠀⠀⠀⠈⠳⣄⠀⠀⠙⢷⡀⠀⠀⠙⢦⡘⢦⠀⠀⠀⠺⢿⠇⢀⠀⢸⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⢠⠎⠀⠀⠀⠀⢀⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⡆⡀⠀⠀⠀⠈⣦⠀⠀⠀⠀⠀⠀⠈⢦⡀⠀⠀⠙⢦⡀⠀⠀⠑⢾⡇⠀⠀⠀⠈⢠⡟⠁⢸⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠁⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⠀⢠⠀⠀⠀⠀⠀⠀⢳⠀⢣⣧⠀⠀⠀⠀⠘⡆⠑⡀⠀⠀⠀⠀⠐⡝⢄⠀⠀⠀⠹⢆⠀⠀⢈⡷⠀⠀⠀⢠⡟⠀⠀⠈⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⢸⣦⠀⠀⠀⠀⠀⢸⡄⢸⢹⣄⣆⠀⠀⠀⠸⡄⠹⡄⠀⠀⠀⠀⠈⢎⢧⡀⠀⠀⠈⠳⣤⡿⠛⠳⡀⠀⡉⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⢸⠇⠀⠀⠀⡇⠀⢸⢸⠀⠀⠀⠀⠀⠘⣿⠀⣿⣿⡙⡄⠀⠀⠀⠹⡄⠘⡄⠀⠀⠀⠀⠈⢧⡱⡄⠀⠀⠀⠛⢷⣦⣤⣽⣶⣶⣶⣦⣤⣸⣀⡀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠸⠀⠀⠀⠀⡇⠀⢸⡸⡆⠀⠀⠀⠀⠀⣿⣇⣿⣿⣷⣽⡖⠒⠒⠊⢻⡉⠹⡏⠒⠂⠀⠀⠀⠳⡜⣦⡀⠀⠀⠀⠹⣿⡟⠋⣿⡻⣯⣍⠉⡉⠛⠶⣄⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⢠⠀⠀⠀⠀⡇⡀⠸⡇⣧⢂⠀⠀⠀⢰⡸⣿⡿⢻⡇⠁⠹⣆⠀⠀⠈⢷⡀⠹⡾⣆⠀⠀⠀⠀⠙⣎⠟⣦⣀⣀⣴⣿⠀⣼⣿⢷⣌⠻⢷⣦⣄⣸⠇⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⢹⣇⠀⣧⢹⡟⡄⠀⠀⠀⣿⢿⠀⡀⢻⡀⠘⣎⢇⢀⣀⣨⣿⣦⠹⣾⣧⡀⠀⠀⣀⣨⠶⠾⣿⣿⣿⣿⣶⡿⣼⡞⠙⢷⣵⡈⠉⠉⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⢸⢠⣠⠤⠒⢺⣿⠒⢿⡼⣿⣳⡀⠀⣠⠋⢿⠆⠰⡄⢳⣤⠼⣿⣯⣶⠿⠿⠿⠿⢿⣿⣷⣶⣿⠁⠀⠀⠀⣻⣿⣿⣿⣿⣷⣿⢡⢇⣾⢻⣿⣶⣄⡀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⢰⣼⢾⡀⠀⠀⠸⣿⡇⠈⣧⢹⡛⢣⡴⠃⠀⠘⣿⡀⣨⠾⣿⣾⠟⢩⣷⣿⣶⣤⠀⠀⠈⢿⡿⣿⠀⠀⠀⠀⢹⢿⣿⣿⣿⣿⠋⢻⠏⢹⣸⠁⠈⠛⠿⣶⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠈⣿⣿⣇⠀⠀⠀⣿⢹⡄⢻⣧⢷⠛⣧⠀⠀⠀⠈⣿⣧⣾⣿⠁⠀⣾⣿⣿⣷⣾⡇⠀⠀⡜⠀⢸⠀⠀⠀⠀⢸⡄⢻⣿⣿⠋⠀⢸⠀⠀⣿⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⢸⣄⠠⣶⣻⣖⣷⡘⣇⠈⢧⠘⣷⠶⠒⠊⠙⣿⠟⠁⠀⠀⢹⡿⣿⣿⢿⠇⠀⠐⠁⠀⢼⠀⠀⠀⠀⡼⢸⠻⣿⣧⣀⠀⠀⢀⣼⢹⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⢹⣿⣿⣿⣿⠟⠛⠛⣿⣿⣿⣦⡈⠠⠘⠆⠀⠀⠈⠁⠀⠀⠀⠀⠈⠛⠶⠞⠋⠀⠀⠀⡀⢠⡏⠀⠀⠀⢠⡇⣼⢸⣿⡟⠉⢣⣠⢾⡇⢸⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⢀⣨⢿⡿⣟⢿⡄⠀⠀⣿⣿⣯⣿⡃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⡇⠀⠀⠀⣼⡿⢱⣿⣿⠁⠀⠈⡇⢸⡇⢠⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⢋⠁⠈⡇⠘⣆⠑⢄⠀⠘⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⠇⠀⠀⢠⢿⣷⣿⣿⣿⡄⠀⠰⠃⣼⡇⢸⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⢻⠀⢹⣆⠀⠁⢤⡌⠓⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⠀⠀⢠⡏⢸⣿⣿⣿⡿⠻⡄⣠⣾⣿⡇⢸⠦⠀⠀⠀ ⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠈⡇⠀⢸⡆⢸⣿⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡸⡏⠀⢀⡟⠀⣾⣿⣿⣿⠀⠀⣽⠁⢸⣿⣷⢸⡇⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⢸⡇⢸⣿⣿⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣴⣿⠁⢠⡟⠀⢰⣿⣿⣿⣿⠀⢠⠇⢠⣾⡇⢿⡈⡇⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠈⠃⢸⣿⣿⣷⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⣿⡏⢀⠎⠀⠀⡼⣽⠋⠁⠈⢀⣾⣴⣿⣿⡇⠸⡇⢱⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⢠⡇⠀⠀⠀⢸⣿⠑⢹⣿⣄⠀⠀⠀⠀⠀⠀⠀⠀⠐⠂⠀⠀⠀⠀⠀⠀⠀⠀⣠⣾⣿⠋⢠⠟⠀⠀⣸⣷⠃⠀⢀⡞⠁⢸⣿⣿⣿⣧⠀⢿⣸⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⢻⠃⠀⠀⠀⣿⡇⠀⣼⣿⣿⣷⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣼⣿⣿⠇⡴⠃⠀⠀⣰⣟⡏⠀⡠⠋⢀⣠⣿⣿⡏⠈⣿⡇⠘⣏⣆⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⢀⡾⠀⠀⠀⢠⣿⠀⠀⣿⣿⡿⢹⣿⡿⠷⣶⣤⣀⡀⠀⠀⠀⠀⠀⠀⢀⣴⣿⣿⣷⢧⡞⠁⠀⠀⣸⣿⠼⠷⢶⣶⣾⣿⡿⣿⡿⠀⠀⠘⣷⠀⠸⣿⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠊⠀⠀⠀⠀⣼⠇⠀⣸⣿⡿⢡⣿⡟⠀⣠⣾⣿⣿⣿⣷⣦⣤⣀⣠⣾⣿⣿⣿⣿⣛⣋⣀⣀⣠⢞⡟⠀⣀⡠⢾⣿⣿⡟⠀⢿⣧⠀⠀⠀⠘⡆⠀⠙⡇⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⡟⠀⢠⣿⠟⢀⣿⡟⢀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠋⠉⠁⠀⠉⠉⠉⠑⠻⢭⡉⠉⠀⢸⡆⢿⡗⠀⠈⢿⡀⠀⠀⠀⠹⡄⠀⢱⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⢀⡼⠁⠀⢀⡞⠉⢠⡿⣌⣴⣿⣿⣿⣿⣿⣿⣿⣿⡿⠛⠋⡿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠲⣄⢸⡇⠘⡇⠀⠀⠈⢧⠀⠀⠀⠀⢱⡀⠈⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⣠⠞⠁⠀⣠⠏⠀⣰⣿⣿⣿⡿⠟⠿⠛⣩⣾⡿⠛⠁⠀⢀⣼⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢿⡇⠀⠸⡄⠀⠀⠈⢇⠀⠀⠀⠀⢻⡀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠁⠀⠀⣠⠇⣠⣾⣿⠿⠛⠁⢀⣠⣴⣿⠟⠁⠀⠀⠀⢰⠋⡏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⡀⠀⠹⡄⠀⠀⠘⢆⠀⠀⠀⠀⠳⡀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⣀⣴⣫⡾⠟⠋⢁⣀⣤⣶⣿⡟⠋⠀⠀⣀⣠⣤⣾⡿⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⡄⠀⢹⡄⠀⠀⠈⢧⡀⠀⠀⠀⠙⣔⡄⠀
 */
interface IBaseV2Gauge {
    /*///////////////////////////////////////////////////////////////
                            GAUGE STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice the reward token paid
    function rewardToken() external returns (address);

    /// @notice the flywheel core contract
    function flywheelGaugeRewards() external returns (FlywheelGaugeRewards);

    /// @notice mapping of whitelisted bribe tokens.
    function isActive(FlywheelCore flywheel) external returns (bool);

    /// @notice if bribe flywheel was already added.
    function added(FlywheelCore flywheel) external returns (bool);

    /// @notice the gauge's strategy contract
    function strategy() external returns (address);

    /// @notice the gauge's rewards depot
    function multiRewardsDepot() external returns (MultiRewardsDepot);

    /// @notice the current epoch / cycle number
    function epoch() external returns (uint256);

    /// @notice returns all bribe flywheels
    function getBribeFlywheels() external view returns (FlywheelCore[] memory);

    /*///////////////////////////////////////////////////////////////
                        GAUGE ACTIONS    
    //////////////////////////////////////////////////////////////*/

    /// @notice function responsible for updating current epoch
    /// @dev should be called once per week, or any outstanding rewards will be kept for next cycle
    function newEpoch() external;

    /// @notice attaches a gauge to a user
    /// @dev only the strategy can call this function
    function attachUser(address user) external;

    /// @notice detaches a gauge to a users
    /// @dev only the strategy can call this function
    function detachUser(address user) external;

    /// @notice accrues bribes for a given user
    /// @dev ERC20Gauges calls this on every vote change
    function accrueBribes(address user) external;

    /*///////////////////////////////////////////////////////////////
                        ADMIN ACTIONS    
    //////////////////////////////////////////////////////////////*/

    /// @notice adds a new bribe flywheel
    /// @dev only owner can call this function
    function addBribeFlywheel(FlywheelCore bribeFlywheel) external;

    /// @notice removes a bribe flywheel
    /// @dev only owner can call this function
    function removeBribeFlywheel(FlywheelCore bribeFlywheel) external;

    /*///////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when weekly emissions are distributed
     * @param amount amount of tokens distributed
     * @param epoch current epoch
     */
    event Distribute(uint256 indexed amount, uint256 indexed epoch);

    /**
     * @notice Emitted when adding a new bribe flywheel
     * @param bribeFlywheel address of the bribe flywheel
     */
    event AddedBribeFlywheel(FlywheelCore indexed bribeFlywheel);

    /**
     * @notice Emitted when removing a bribe flywheel
     * @param bribeFlywheel address of the bribe flywheel
     */
    event RemoveBribeFlywheel(FlywheelCore indexed bribeFlywheel);

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice thrown when caller is not the strategy
    error StrategyError();

    /// @notice thrown when trying to add an existing flywheel
    error FlywheelAlreadyAdded();

    /// @notice thrown when trying to add an existing flywheel
    error FlywheelNotActive();
}
