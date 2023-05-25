// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {FlywheelGaugeRewards} from "@rewards/rewards/FlywheelGaugeRewards.sol";

import {UniswapV3Staker} from "@v3-staker/UniswapV3Staker.sol";

import {IBaseV2GaugeFactory} from "./IBaseV2GaugeFactory.sol";

/**
 * @title Uniswap V3 Gauge Factory
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice Handles the creation of new Uniswap V3 gauges and the management of existing ones.
 *          Adds and removes gauges, and allows the bribe factory
 *          to add and remove bribes to gauges.
 *
 * ⠀⠀⠀⠀⠀⠀⠀⣠⠊⡴⠁⠀⠀⣰⠏⠀⣼⠃⢰⡇⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⡇⠙⡄⠀⠀⠳⠙⡆⠀⠀⠘⣆⠀⠀
 * ⠀⠀⠀⠀⢀⣀⡔⠁⡞⠁⠀⠀⣴⠃⠀⣰⡏⠀⠇⠀⠀⠀⠀⠀⠀⠀⡄⠀⢻⠀⠀⠀⠀⠀⠀⠀⢸⠀⠘⡄⠀⠀⠀⢹⡄⠀⠀⠸⠀⠀
 * ⠀⠀⠀⠀⢀⡏⠀⠜⠀⠀⠀⣼⠇⠀⢠⣿⠁⣾⢸⠀⠀⠀⠀⠀⠀⠀⡇⠀⢸⡇⠀⢢⠀⠀⠀⢆⠀⣇⠀⠘⡄⠀⠀⠘⡇⠀⠀⠀⠀⠀
 * ⠀⠀⠀⢀⡾⠀⠀⠀⠀⠀⣸⠏⠀⠀⡞⢹⠀⡇⡾⠀⠀⠀⠀⠀⠀⠀⢰⠀⠀⣿⡀⠈⢇⠀⠀⠈⢧⣿⡀⠀⠀⠀⠀⠀⠇⠀⠀⠀⠀⠀
 * ⠀⠀⠀⣼⡇⠀⠀⠀⠀⢠⡿⠀⠀⢠⠁⢸⠀⡇⢳⡇⠀⠀⠀⠀⠀⠀⢸⡀⠀⢸⣧⠀⠘⡄⠀⠀⠀⠻⣷⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠐⢸⡇⠀⡄⠀⠀⠸⣿⠀⠀⣼⠤⠐⣇⢣⡀⠳⡀⠀⠀⢠⠀⠀⠘⣇⠀⠀⢻⣏⠉⢻⡒⠤⡀⠀⠘⠣⣄⡆⠀⠀⠀⠀⠀⠀⠀⠀
 * ⡄⠀⠸⡌⣧⠀⢧⠀⠀⠀⢿⣧⠀⢹⠀⠀⠘⢦⠙⠒⠳⠦⠤⣈⣳⠄⠀⠽⢷⠤⠈⠨⠧⢄⠳⣄⣠⡦⡀⠀⠀⣉⣑⣲⡇⠀⠀⠀⠀⠀
 * ⣌⢢⡀⠙⢻⠳⣬⣧⣀⠠⡈⣏⠙⣋⣥⣶⣶⣤⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⡶⠾⣶⡶⣶⣧⣶⢹⣷⠚⡗⠋⢹⠉⠀⠀⠀⠀⠀⠀⠀
 * ⠈⠳⣹⣦⡀⠀⣿⣼⠋⠉⢉⣽⣿⡋⣷⣦⣿⣿⣷⡀⠀⠀⢀⣤⣶⠭⠭⢿⣧⣀⣴⣻⣥⣾⣏⣿⠀⢸⡀⠁⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠘⢮⣻⡄⢿⢻⢀⣾⡿⠟⠛⢻⡽⣱⡟⣩⢿⡷⣶⣶⣾⡿⠁⢤⡖⠒⠛⣿⠟⣥⣛⢷⣿⣽⠀⠘⡿⠁⠀⡟⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠰⡙⢿⡼⡜⢸⣿⠒⡿⢦⠎⣴⢏⡜⠀⢸⣿⠁⠀⢹⣧⠀⠘⡿⢷⡾⣅⡠⠞⠛⠿⣟⣿⡆⠀⢧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠐⠒⠲⣄⢳⢈⡇⡇⠈⢿⣷⣷⢁⣾⢃⠞⠀⣠⡿⠃⠤⡀⠚⢿⣆⡠⠊⠢⡀⠀⠙⠦⣀⣴⣷⠋⣧⠀⠈⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⢠⡀⠀⠘⢻⣾⠃⠃⠀⢸⠻⣿⣿⣥⣋⣠⣾⠟⠁⠀⠀⠀⠀⠈⢻⣧⡀⠀⠈⢲⣄⡀⠈⠛⢁⡀⠟⡄⠀⠸⡀⡀⠀⠀⠠⠀⠀⠀⠀⠀
 * ⠀⠱⣄⠀⠈⢻⡏⠀⠀⠈⡄⢿⠈⠙⠛⠛⠁⠀⠀⠀⠀⠀⠀⠀⠀⠹⢿⠶⢚⡯⠗⠋⠲⢄⠀⠈⠒⢿⡄⠀⠱⣇⠀⢀⡇⠀⠀⠀⠀⠀
 * ⢀⡀⠙⣧⡀⣸⡇⠀⠀⠀⠇⢸⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠀⠀⠀⠀⠀⠀⠙⢦⣀⠀⠈⠲⢄⠙⣆⣸⡇⠀⠀⠀⠀⠀
 * ⡻⣷⣦⡼⣷⣿⠃⠀⠀⠀⢸⠈⡟⢆⣀⠴⠊⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⢴⠚⠉⠉⠉⠀⣀⠔⣋⠡⠽⢷⠀⠀⠀⠀⠀
 * ⠁⠈⢻⡇⢻⣿⠀⠀⠀⠀⠀⣆⢿⠿⡓⢦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡠⣽⣿⣀⡤⠎⡔⢊⠔⢊⡁⠤⠖⢚⣳⣄⠀⠀⠀
 * ⠀⢀⢸⢀⢸⡇⠀⠀⠀⠀⠀⠸⡘⡆⢧⠀⢿⢢⣀⠀⠀⠀⠀⠀⠀⢀⣀⠤⠒⠊⣡⢤⡏⡼⢏⠀⡜⣰⠁⡰⠋⣠⠒⠈⢁⣀⠬⠧⡀⠀
 * ⠀⠀⢸⠈⡞⣧⠀⠀⠀⠀⠀⠀⢣⢹⣮⣆⢸⠸⡌⠓⡦⠒⠒⠊⠉⠁⠀⠀⢠⠞⠀⢠⣿⠁⣸⠻⣡⠃⡼⠀⡰⠁⣠⠞⠁⣠⠤⠐⠚⠀
 * ⠀⠀⡸⠀⣷⢻⠀⠀⠀⠀⠀⠀⢀⢷⡈⢿⣄⡇⢹⡀⢱⠀⠀⠀⠀⠀⢀⠜⠁⠀⠀⣼⣻⣰⡏⠀⠙⢶⠀⡴⠁⡔⠁⣠⠊⢀⠔⠋⠀⠀
 * ⠀⠀⠇⢀⡿⡼⣇⠀⠀⠸⠀⠀⠀⠻⣷⡈⢟⢿⡀⠳⣾⣀⣄⣀⡠⠞⠁⠀⢀⣀⣴⢿⡿⡹⠀⠀⠀⠀⢹⣅⡞⠀⡴⠁⡰⠃⠀⡀⠀⠀
 * ⠀⠀⢠⡾⠀⠱⡈⢦⡀⠀⢳⡀⠀⠀⠈⢯⠿⣦⡳⣴⡟⠛⠋⣿⣴⣶⣶⣿⣿⠿⣯⡞⠀⠃⠀⠀⠀⠀⠈⣿⣑⣞⣀⡜⠁⡴⠋⠀⠀⠀
 * ⠀⠀⢠⠇⠀⢀⣈⣒⠻⣦⣀⠱⣄⡀⠀⠀⠓⣬⣳⣽⠳⣤⠼⠋⠉⠉⠉⠀⣀⣴⣿⠁⠀⠀⠀⠀⠀⠀⢰⠋⣉⡏⡍⠙⡎⢀⡼⠁⠀⠀
 * ⠀⣰⣓⣢⠝⠋⣠⣴⡜⠺⠛⠛⠿⠿⣓⣶⠋⠀⠤⠃⠀⠀⠀⠀⠀⢀⣤⡾⢻⠟⡏⠀⠀⠀⠀⠀⠀⡇⡝⠉⡠⢤⣳⠀⣷⢋⡴⠁⠀⠀
 * ⠜⠿⣿⣦⣖⢉⠰⣁⣉⣉⣉⣉⣑⠒⠼⣿⣆⠀⠀⠀⠀⠀⣀⣠⣶⠿⠓⠊⠉⠉⠁⠀⠀⠀⠀⠀⠀⢠⠴⢋⡠⠤⢏⣷⣿⣉⠀⠀⠀
 */
interface IUniswapV3GaugeFactory is IBaseV2GaugeFactory {
    /*//////////////////////////////////////////////////////////////
                         FACTORY STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The uniswap v3 staker instance.
    function uniswapV3Staker() external view returns (UniswapV3Staker);

    /// @notice Flywheel for the uniswap v3 staker, that is responsible for distributing the rewards.
    function flywheelGaugeRewards() external view returns (FlywheelGaugeRewards);

    /*//////////////////////////////////////////////////////////////
                         ADMIN LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the minimum width for gauge
    function setMinimumWidth(address gauge, uint24 minimumWidth) external;
}
