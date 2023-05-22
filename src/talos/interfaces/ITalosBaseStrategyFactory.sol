// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {TalosBaseStrategy} from "../base/TalosBaseStrategy.sol";
import {OptimizerFactory, TalosOptimizer} from "../factories/OptimizerFactory.sol";

import {ITalosOptimizer} from "../interfaces/ITalosOptimizer.sol";

/**
 * @title Talos Base Strategy Factory
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice This contract is used to create new TalosBaseStrategy contracts.
 */
interface ITalosBaseStrategyFactory {
    /*//////////////////////////////////////////////////////////////
                        TALOS BASE FACTORY STATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the nonfungible position manager used by the factory.
     */
    function nonfungiblePositionManager() external view returns (INonfungiblePositionManager);

    /**
     * @notice Returns the optimizer factory used by this contract.
     */
    function optimizerFactory() external view returns (OptimizerFactory);

    /**
     * @notice Keeps track of the strategies created by the factory.
     */
    function strategies(uint256) external view returns (TalosBaseStrategy);

    /**
     * @notice Maps the created strategies to an incremental id.
     */
    function strategyIds(TalosBaseStrategy) external view returns (uint256);

    /**
     * @notice Returns all the strategies created by the factory.
     */
    function getStrategies() external view returns (TalosBaseStrategy[] memory);

    /*//////////////////////////////////////////////////////////////
                            CREATE LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new strategy
     * @param pool The address of the pool to create a talos strategy for.
     * @param optimizer Address of the optimizer attached to the strategy.
     * @param strategyManager Address of the manager of the strategy.
     * @param data Additional data needed to create the strategy
     */
    function createTalosBaseStrategy(
        IUniswapV3Pool pool,
        ITalosOptimizer optimizer,
        address strategyManager,
        bytes memory data
    ) external;

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Error emitted when the optimizer is not recognized.
    error UnrecognizedOptimizer();

    /// @notice Error emitted when the strategy manager is not recognized.
    error UnrecognizedStrategyManager();
}
