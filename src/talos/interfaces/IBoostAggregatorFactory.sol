// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {UniswapV3Staker} from "@v3-staker/UniswapV3Staker.sol";

import {BoostAggregator} from "../boost-aggregator/BoostAggregator.sol";

/**
 * @title Boost Aggregator Factory
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice This contract is responsible for creating new BoostAggregators.
 */
interface IBoostAggregatorFactory {
    /*//////////////////////////////////////////////////////////////
                    BOOST AGGREGATOR FACTORY STATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Underlying uniV3Staker contract
     */
    function uniswapV3Staker() external view returns (UniswapV3Staker);

    /**
     * @notice Underlying hermes token contract.
     */
    function hermes() external view returns (ERC20);

    /**
     * @notice Holds every boost created by the factory.
     */
    function boostAggregators(uint256) external view returns (BoostAggregator);

    /**
     * @notice Maps every created boost to an incremental id.
     */
    function boostAggregatorIds(BoostAggregator) external view returns (uint256);

    /**
     * @notice Returns the boost aggregators created by the factory.
     */
    function getBoostAggregators() external view returns (BoostAggregator[] memory);

    /*//////////////////////////////////////////////////////////////
                         GAUGE LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new boostAggregator
     * @param owner The owner of the boostAggregator
     */
    function createBoostAggregator(address owner) external;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the owner of the BoostAggregator is the zero address.
    error InvalidOwner();
}
