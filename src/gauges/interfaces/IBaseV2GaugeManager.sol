// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {bHermesBoost} from "@hermes/tokens/bHermesBoost.sol";
import {bHermesGauges} from "@hermes/tokens/bHermesGauges.sol";

import {BaseV2GaugeFactory} from "../factories/BaseV2GaugeFactory.sol";

/**
 * @title Base V2 Gauge Factory Manager
 * @notice Interface for the BaseV2GaugeManager contract that handles the
 *         management of gauges and gauge factories.
 *
 *         @dev Only this contract can add/remove gauges to bHermesWeight and bHermesBoost.
 * @author Maia DAO (https://github.com/Maia-DAO)
 */
interface IBaseV2GaugeManager {
    /*///////////////////////////////////////////////////////////////
                        GAUGE MANAGER STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Address that holds admin power over the contract.
    function admin() external view returns (address);

    /// @notice Represent the underlying gauge voting power of bHermes.
    function bHermesGaugeWeight() external view returns (bHermesGauges);

    /// @notice Represents the boosting power of bHermes.
    function bHermesGaugeBoost() external view returns (bHermesBoost);

    /// @notice Array that holds every gauge factory.
    function gaugeFactories(uint256) external view returns (BaseV2GaugeFactory);

    /// @notice Maps each gauge factory to an incremental id.
    function gaugeFactoryIds(BaseV2GaugeFactory) external view returns (uint256);

    /// @notice Holds all the active gauge factories.
    function activeGaugeFactories(BaseV2GaugeFactory) external view returns (bool);

    /// @notice Returns all the gauge factories (including the inactive ones).
    function getGaugeFactories() external view returns (BaseV2GaugeFactory[] memory);

    /*//////////////////////////////////////////////////////////////
                            EPOCH LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Function to call at the beginning of every epoch.
    function newEpoch() external;

    /**
     * @notice Performs the necessary operations of the beginning of the new epoch for a given gauge ids range.
     * @param start initial gauge id to perform the actions.
     * @param end end gauge id to perform the actions.
     */
    function newEpoch(uint256 start, uint256 end) external;

    /*//////////////////////////////////////////////////////////////
                            GAUGE LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a gauge to a bhermes position.
     * @param gauge gauge address to add.
     */
    function addGauge(address gauge) external;

    /**
     * @notice Removes a gauge to a bhermes position.
     * @param gauge gauge address to remove.
     */
    function removeGauge(address gauge) external;

    /*//////////////////////////////////////////////////////////////
                            OWNER LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a gauge factory to the manager.
     * @param gaugeFactory gauge factory address to add to the manager.
     */
    function addGaugeFactory(BaseV2GaugeFactory gaugeFactory) external;

    /**
     * @notice Removes a gauge factory from the manager.
     * @param gaugeFactory gauge factory address to remove to the manager.
     */
    function removeGaugeFactory(BaseV2GaugeFactory gaugeFactory) external;

    /*//////////////////////////////////////////////////////////////
                            ADMIN LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Changes the ownership of the bHermes gauge boost and gauge weight properties.
     * @param newOwner address of the new owner.
     */
    function changebHermesGaugeOwner(address newOwner) external;

    /**
     * @notice Changes the admin powers of the manager.
     * @param newAdmin address of the new admin.
     */
    function changeAdmin(address newAdmin) external;

    /*///////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new gauge factory is added.
    event AddedGaugeFactory(address gaugeFactory);

    /// @notice Emitted when a gauge factory is removed.
    event RemovedGaugeFactory(address gaugeFactory);

    /// @notice Emitted when changing bHermes GaugeWeight and GaugeWeight owner.
    event ChangedbHermesGaugeOwner(address newOwner);

    /// @notice Emitted when changing admin.
    event ChangedAdmin(address newAdmin);

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Throws when trying to add a gauge factory that already exists.
    error GaugeFactoryAlreadyExists();

    /// @dev Throws when the caller is not an active gauge factory.
    error NotActiveGaugeFactory();

    /// @dev Throws when the caller is not the admin.
    error NotAdmin();
}
