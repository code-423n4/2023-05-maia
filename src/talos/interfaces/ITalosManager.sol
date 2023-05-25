// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ITalosBaseStrategy} from "./ITalosBaseStrategy.sol";

import {AutomationCompatibleInterface} from "./AutomationCompatibleInterface.sol";

/**
 *  @title  Talos Strategy Manager - Manages rebalancing and reranging of Talos Positions
 *  @notice TalosManager is a Uniswap V3 yield enhancement contract which acts as
 *          intermediary between the user who wants to provide liquidity to specific pools
 *          and earn fees from such actions. The contract ensures that user position is in
 *          range and earns the maximum amount of fees available at current liquidity
 *          utilization rate.
 */
interface ITalosManager is AutomationCompatibleInterface {
    /*//////////////////////////////////////////////////////////////
                        TALOS OPTIMIZER STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice ticks from lower range to rebalance
    function ticksFromLowerRebalance() external view returns (int24);

    /// @notice ticks from upper range to rebalance
    function ticksFromUpperRebalance() external view returns (int24);

    /// @notice ticks from lower range to rerange
    function ticksFromLowerRerange() external view returns (int24);

    /// @notice ticks from upper range to rerange
    function ticksFromUpperRerange() external view returns (int24);

    /// @notice TALOS strategy to rebalance or rerange
    function strategy() external view returns (ITalosBaseStrategy);
}
