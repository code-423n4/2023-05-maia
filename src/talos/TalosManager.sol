// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {ITalosBaseStrategy} from "./interfaces/ITalosBaseStrategy.sol";
import {ITalosManager} from "./interfaces/ITalosManager.sol";
import {ITalosOptimizer} from "./interfaces/ITalosOptimizer.sol";
import {PoolVariables} from "./libraries/PoolVariables.sol";

import {ITalosManager, AutomationCompatibleInterface} from "./interfaces/ITalosManager.sol";

/// @title Talos Strategy Manager - Manages rebalancing and reranging of Talos Positions
contract TalosManager is AutomationCompatibleInterface, ITalosManager {
    using PoolVariables for IUniswapV3Pool;

    /*//////////////////////////////////////////////////////////////
                        TALOS OPTIMIZER STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITalosManager
    int24 public immutable ticksFromLowerRebalance;

    /// @inheritdoc ITalosManager
    int24 public immutable ticksFromUpperRebalance;

    /// @inheritdoc ITalosManager
    int24 public immutable ticksFromLowerRerange;

    /// @inheritdoc ITalosManager
    int24 public immutable ticksFromUpperRerange;

    /// @inheritdoc ITalosManager
    ITalosBaseStrategy public immutable strategy;

    /**
     * @notice Construct a new Talos Strategy Manager contract.
     * @param _strategy Strategy to manage.
     * @param _ticksFromLowerRebalance Ticks from lower tick to rebalance.
     * @param _ticksFromUpperRebalance Ticks from upper tick to rebalance.
     * @param _ticksFromLowerRerange Ticks from lower tick to rerange.
     * @param _ticksFromUpperRerange Ticks from upper tick to rerange.
     */
    constructor(
        address _strategy,
        int24 _ticksFromLowerRebalance,
        int24 _ticksFromUpperRebalance,
        int24 _ticksFromLowerRerange,
        int24 _ticksFromUpperRerange
    ) {
        strategy = ITalosBaseStrategy(_strategy);
        ticksFromLowerRebalance = _ticksFromLowerRebalance;
        ticksFromUpperRebalance = _ticksFromUpperRebalance;
        ticksFromLowerRerange = _ticksFromLowerRerange;
        ticksFromUpperRerange = _ticksFromUpperRerange;
    }

    /*//////////////////////////////////////////////////////////////
                        UPKEEP ACTION CHECKERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns true if strategy needs to be rebalanced
     * @dev Checks if current tick is in range, returns true if not
     */
    function getRebalance(ITalosBaseStrategy position) private view returns (bool) {
        //Calculate base ticks.
        (, int24 currentTick,,,,,) = position.pool().slot0();

        return currentTick - position.tickLower() >= ticksFromLowerRebalance
            || position.tickUpper() - currentTick >= ticksFromUpperRebalance;
    }

    /**
     * @notice Returns true if strategy needs to be reranged
     * @dev Checks if current tick is in range, returns true if not
     */
    function getRerange(ITalosBaseStrategy position) private view returns (bool) {
        //Calculate base ticks.
        (, int24 currentTick,,,,,) = position.pool().slot0();

        return currentTick - position.tickLower() >= ticksFromLowerRerange
            || position.tickUpper() - currentTick >= ticksFromUpperRerange;
    }

    /*//////////////////////////////////////////////////////////////
                            AUTOMATION
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc AutomationCompatibleInterface
    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) {
        ITalosOptimizer optimizer = strategy.optimizer();

        // checks if price has not moved a lot recently.
        // This mitigates price manipulation during rebalance and also prevents placing orders when it's too volatile.
        try strategy.pool().checkDeviation(optimizer.maxTwapDeviation(), optimizer.twapDuration()) {}
        catch {
            return (false, "");
        }

        if (getRebalance(strategy)) {
            upkeepNeeded = true;
        } else if (getRerange(strategy)) {
            upkeepNeeded = true;
        }

        performData = "";
    }

    /// @inheritdoc AutomationCompatibleInterface
    /// @notice Rebalances or Reranges an Optimizer's positions.
    function performUpkeep(bytes calldata) external override {
        if (getRebalance(strategy)) {
            /**
             * @dev Swaps imbalanced token. Finds base position and limit position for imbalanced token if
             * we don't have balance during swap because of price impact.
             * mints all amounts to this position(including earned fees)
             */
            strategy.rebalance();
        } else if (getRerange(strategy)) {
            /**
             * @dev Finds base position and limit position for imbalanced token
             * mints all amounts to this position(including earned fees)
             */
            strategy.rerange();
        }
    }
}
