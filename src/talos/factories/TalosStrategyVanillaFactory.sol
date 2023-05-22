// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import {TalosBaseStrategy} from "../base/TalosBaseStrategy.sol";
import {DeployVanilla, TalosStrategyVanilla} from "../TalosStrategyVanilla.sol";
import {TalosManager} from "../TalosManager.sol";

import {OptimizerFactory} from "./OptimizerFactory.sol";
import {TalosBaseStrategyFactory} from "./TalosBaseStrategyFactory.sol";

import {ITalosOptimizer} from "../interfaces/ITalosOptimizer.sol";

/// @title Talos Strategy Vanilla Factory
contract TalosStrategyVanillaFactory is TalosBaseStrategyFactory {
    /**
     * @notice Construct a new Talos Strategy Vanilla Factory
     * @param _nonfungiblePositionManager The Uniswap V3 NFT Manager
     * @param _optimizerFactory The Optimizer Factory
     */
    constructor(INonfungiblePositionManager _nonfungiblePositionManager, OptimizerFactory _optimizerFactory)
        TalosBaseStrategyFactory(_nonfungiblePositionManager, _optimizerFactory)
    {}

    /*//////////////////////////////////////////////////////////////
                         GAUGE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal function responsible for creating a new Talos Strategy
    function createTalosV3Strategy(
        IUniswapV3Pool pool,
        ITalosOptimizer optimizer,
        address strategyManager,
        bytes memory
    ) internal override returns (TalosBaseStrategy) {
        return DeployVanilla.createTalosV3Vanilla(pool, optimizer, nonfungiblePositionManager, strategyManager, owner());
    }
}
