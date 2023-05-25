// SPDX-License-Identifier: MIT
// Logic inspired by Popsicle Finance Contracts (PopsicleV3Optimizer/contracts/libraries/PoolActions.sol)
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import {ITalosOptimizer} from "@talos/interfaces/ITalosOptimizer.sol";

import {PoolVariables} from "./PoolVariables.sol";

/// @title Pool Actions - Library for conducting uniswap v3 pool actions
/// @author MaiaDAO
/// @notice This library is created to conduct a variety of swap, burn and add liquidity methods.
library PoolActions {
    using PoolVariables for IUniswapV3Pool;

    /// @notice Shows current Optimizer's balances
    /// @param totalAmount0 Current token0 Optimizer's balance
    /// @param totalAmount1 Current token1 Optimizer's balance
    event Snapshot(uint256 totalAmount0, uint256 totalAmount1);

    //Any data passed through by the caller via the IUniswapV3PoolActions#swap call
    struct SwapCallbackData {
        bool zeroForOne;
    }

    struct ActionParams {
        IUniswapV3Pool pool;
        ITalosOptimizer optimizer;
        ERC20 token0;
        ERC20 token1;
        int24 tickSpacing;
    }

    function swapToEqualAmounts(ActionParams memory actionParams, int24 baseThreshold) internal {
        (bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96) = actionParams
            .pool
            .getSwapToEqualAmountsParams(
            actionParams.optimizer, actionParams.tickSpacing, baseThreshold, actionParams.token0, actionParams.token1
        );

        //Swap imbalanced token as long as we haven't used the entire amountSpecified and haven't reached the price limit
        actionParams.pool.swap(
            address(this),
            zeroForOne,
            amountSpecified,
            sqrtPriceLimitX96,
            abi.encode(SwapCallbackData({zeroForOne: zeroForOne}))
        );
    }

    // Rerange a pool according to ITalosOptimizer's parameters
    function rerange(
        INonfungiblePositionManager nonfungiblePositionManager,
        ActionParams memory actionParams,
        uint24 poolFee
    )
        internal
        returns (int24 tickLower, int24 tickUpper, uint256 amount0, uint256 amount1, uint256 tokenId, uint128 liquidity)
    {
        int24 baseThreshold = actionParams.tickSpacing * actionParams.optimizer.tickRangeMultiplier();

        uint256 balance0;
        uint256 balance1;
        (balance0, balance1, tickLower, tickUpper) = getThisPositionTicks(
            actionParams.pool, actionParams.token0, actionParams.token1, baseThreshold, actionParams.tickSpacing
        );
        emit Snapshot(balance0, balance1);

        (tokenId, liquidity, amount0, amount1) = nonfungiblePositionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: address(actionParams.token0),
                token1: address(actionParams.token1),
                fee: poolFee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: balance0,
                amount1Desired: balance1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );
    }

    function getThisPositionTicks(
        IUniswapV3Pool pool,
        ERC20 token0,
        ERC20 token1,
        int24 baseThreshold,
        int24 tickSpacing
    ) private view returns (uint256 balance0, uint256 balance1, int24 tickLower, int24 tickUpper) {
        // Emit snapshot to record balances
        balance0 = token0.balanceOf(address(this));
        balance1 = token1.balanceOf(address(this));

        //Get exact ticks depending on Optimizer's balances
        (tickLower, tickUpper) = pool.getPositionTicks(balance0, balance1, baseThreshold, tickSpacing);
    }
}
