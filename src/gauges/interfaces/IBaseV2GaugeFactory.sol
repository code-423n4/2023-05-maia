// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {BaseV2Gauge} from "@gauges/BaseV2Gauge.sol";
import {bHermesBoost} from "@hermes/tokens/bHermesBoost.sol";

import {BaseV2GaugeManager} from "../factories/BaseV2GaugeManager.sol";

import {BribesFactory} from "../factories/BribesFactory.sol";

/**
 * @title Base V2 Gauge Factory
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice Handles the creation of new gauges and the management of existing ones.
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
interface IBaseV2GaugeFactory {
    /*///////////////////////////////////////////////////////////////
                            FACTORY STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The gauge factory manager
    function gaugeManager() external view returns (BaseV2GaugeManager);

    /// @notice The bHermes token used for boost accounting
    function bHermesBoostToken() external view returns (bHermesBoost);

    /// @notice The factory of bribe flywheels
    function bribesFactory() external view returns (BribesFactory);

    /// @notice Stores all the gauges created by the factory.
    function gauges(uint256) external view returns (BaseV2Gauge);

    /// @notice Mapping that assigns each gauge an incremental Id for internal use.
    function gaugeIds(BaseV2Gauge) external view returns (uint256);

    /// @notice Mapping to keep track of active gauges.
    function activeGauges(BaseV2Gauge) external view returns (bool);

    /// @notice Associates a strategy address with a gauge.
    function strategyGauges(address) external view returns (BaseV2Gauge);

    /// @notice Returns all the gauges created by this factory.
    function getGauges() external view returns (BaseV2Gauge[] memory);

    /*//////////////////////////////////////////////////////////////
                         EPOCH LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Function to be called after a new epoch begins.
    function newEpoch() external;

    /**
     * @notice Function to be called after a new epoch begins for a specific range of gauges ids.
     * @param start id of the gauge to start the new epoch
     * @param end id of the end gauge to start the new epoch
     */
    function newEpoch(uint256 start, uint256 end) external;

    /*//////////////////////////////////////////////////////////////
                         GAUGE LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new gauge for the given strategy.
     * @param strategy The strategy address to create a gauge for.
     * @param data The information to pass to create a new gauge.
     */
    function createGauge(address strategy, bytes memory data) external;

    /**
     * @notice Removes a gauge and its underlying strategies from existence.
     * @param gauge gauge address to remove.
     */
    function removeGauge(BaseV2Gauge gauge) external;

    /*//////////////////////////////////////////////////////////////
                           BRIBE LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new bribe to the gauge if the bribe address is already pre-approved by governance.
     * @param gauge address of the gauge to add a new bribe.
     * @param bribeToken address of the token to bribe the gauge with.
     */
    function addBribeToGauge(BaseV2Gauge gauge, address bribeToken) external;

    /// @notice Removes a given bribe from a gauge, contingent on the removal being pre-approved by governance.
    function removeBribeFromGauge(BaseV2Gauge gauge, address bribeToken) external;

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Throws when trying to add a gauge that already exists.
    error GaugeAlreadyExists();

    /// @notice Throws when the caller is not the owner or BribesFactory owner.
    error NotOwnerOrBribesFactoryOwner();

    /// @notice Throws when removing an invalid gauge.
    error InvalidGauge();
}
