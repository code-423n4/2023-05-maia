// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FlywheelCoreInstant} from "@rewards/FlywheelCoreInstant.sol";
import {FlywheelInstantRewards} from "@rewards/rewards/FlywheelInstantRewards.sol";

import {BoostAggregatorFactory} from "../factories/BoostAggregatorFactory.sol";

/**
 * @title Talos Strategy Staked Factory
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice This contract is used to create new TalosStrategyStaked contracts.
 */
interface ITalosStrategyStakedFactory {
    /*//////////////////////////////////////////////////////////////
                        TALOS STAKED STRATEGY STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The boostAggregator to stake NFTs in Uniswap V3 Staker
    /// @return boostAggregatorFactory
    function boostAggregatorFactory() external view returns (BoostAggregatorFactory);

    /// @notice flywheel core responsible for assigning strategy rewards
    ///         to its respective users.
    /// @return flywheel
    function flywheel() external view returns (FlywheelCoreInstant);

    /// @notice flywheel core responsible for assigning strategy rewards
    ///         to its respective users.
    /// @return flywheel
    function rewards() external view returns (FlywheelInstantRewards);

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Throws when boostAggregator has an invalid nonfungiblePositionManager
    error InvalidNFTManager();
}
