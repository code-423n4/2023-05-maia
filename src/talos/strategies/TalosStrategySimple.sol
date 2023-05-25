// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {TalosBaseStrategy} from "../base/TalosBaseStrategy.sol";

import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {PoolActions} from "../libraries/PoolActions.sol";

import {ITalosOptimizer} from "../interfaces/ITalosOptimizer.sol";

/// @title Rebalacing and reranging strategies for TALOS UniswapV3 LPs
/// @author Maia DAO (https://github.com/Maia-DAO)
abstract contract TalosStrategySimple is TalosBaseStrategy {
    using PoolActions for INonfungiblePositionManager;

    constructor(
        IUniswapV3Pool _pool,
        ITalosOptimizer _strategy,
        INonfungiblePositionManager _nonfungiblePositionManager,
        address _strategyManager,
        address _owner
    ) TalosBaseStrategy(_pool, _strategy, _nonfungiblePositionManager, _strategyManager, _owner) {}

    // /*//////////////////////////////////////////////////////////////
    //                     RERANGE/REBALANCE LOGIC
    // //////////////////////////////////////////////////////////////*/

    function doRerange() internal override returns (uint256 amount0, uint256 amount1) {
        (tickLower, tickUpper, amount0, amount1, tokenId, liquidity) = nonfungiblePositionManager.rerange(
            PoolActions.ActionParams(pool, optimizer, token0, token1, tickSpacing), poolFee
        );
    }

    function doRebalance() internal override returns (uint256 amount0, uint256 amount1) {
        int24 baseThreshold = tickSpacing * optimizer.tickRangeMultiplier();

        PoolActions.ActionParams memory actionParams =
            PoolActions.ActionParams(pool, optimizer, token0, token1, tickSpacing);

        PoolActions.swapToEqualAmounts(actionParams, baseThreshold);

        (tickLower, tickUpper, amount0, amount1, tokenId, liquidity) =
            nonfungiblePositionManager.rerange(actionParams, poolFee);
    }
}
