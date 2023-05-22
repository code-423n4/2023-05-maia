// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {TalosBaseStrategy} from "../base/TalosBaseStrategy.sol";

import {OptimizerFactory, TalosOptimizer} from "./OptimizerFactory.sol";

import {ITalosOptimizer} from "../interfaces/ITalosOptimizer.sol";
import {ITalosBaseStrategyFactory} from "../interfaces/ITalosBaseStrategyFactory.sol";

/// @title Talos Base Strategy Factory
abstract contract TalosBaseStrategyFactory is Ownable, ITalosBaseStrategyFactory {
    /*//////////////////////////////////////////////////////////////
                        TALOS BASE FACTORY STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITalosBaseStrategyFactory
    INonfungiblePositionManager public immutable nonfungiblePositionManager;

    /// £inheritdoc ITalosBaseStrategyFactory
    OptimizerFactory public immutable optimizerFactory;

    /// @inheritdoc ITalosBaseStrategyFactory
    TalosBaseStrategy[] public strategies;

    /// @inheritdoc ITalosBaseStrategyFactory
    mapping(TalosBaseStrategy => uint256) public strategyIds;

    /**
     * @notice Constructs the Talos Strategy Factory
     * @param _nonfungiblePositionManager The nonfungible position manager used by the factory.
     * @param _optimizerFactory The optimizer factory used by the factory.
     */
    constructor(INonfungiblePositionManager _nonfungiblePositionManager, OptimizerFactory _optimizerFactory) {
        _initializeOwner(msg.sender);
        nonfungiblePositionManager = _nonfungiblePositionManager;
        optimizerFactory = _optimizerFactory;
    }

    /// @inheritdoc ITalosBaseStrategyFactory
    function getStrategies() external view returns (TalosBaseStrategy[] memory) {
        return strategies;
    }

    /*//////////////////////////////////////////////////////////////
                            CREATE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITalosBaseStrategyFactory
    function createTalosBaseStrategy(
        IUniswapV3Pool pool,
        ITalosOptimizer optimizer,
        address strategyManager,
        bytes memory data
    ) external {
        if (optimizerFactory.optimizerIds(TalosOptimizer(address(optimizer))) == 0) {
            revert UnrecognizedOptimizer();
        }

        TalosBaseStrategy strategy = createTalosV3Strategy(pool, optimizer, strategyManager, data);

        strategyIds[strategy] = strategies.length;
        strategies.push(strategy);
    }

    /// @notice Internal function responsible for creating a new Talos Strategy
    function createTalosV3Strategy(
        IUniswapV3Pool pool,
        ITalosOptimizer optimizer,
        address strategyManager,
        bytes memory data
    ) internal virtual returns (TalosBaseStrategy);
}
