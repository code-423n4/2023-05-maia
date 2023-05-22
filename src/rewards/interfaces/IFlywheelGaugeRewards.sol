// SPDX-License-Identifier: MIT
// Rewards logic inspired by Tribe DAO Contracts (flywheel-v2/src/rewards/FlywheelGaugeRewards.sol)
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {ERC20Gauges} from "@ERC20/ERC20Gauges.sol";

import {FlywheelCore} from "../base/FlywheelCore.sol";

/// @notice a contract that streams reward tokens to the FlywheelRewards module
interface IRewardsStream {
    /// @notice read and transfer reward token chunk to FlywheelRewards module
    function getRewards() external returns (uint256);
}

/**
 * @title Flywheel Gauge Reward Stream
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice Distributes rewards from a stream based on gauge weights
 *
 *  The contract assumes an arbitrary stream of rewards `S` of the rewardToken. It chunks the rewards into cycles of length `l`.
 *
 *  The allocation function for each cycle A(g, S) proportions the stream to each gauge such that SUM(A(g, S)) over all gauges <= S.
 *  NOTE it should be approximately S, but may be less due to truncation.
 *
 *  Rewards are accumulated every time a new rewards cycle begins, and all prior rewards are cached in the previous cycle.
 *  When the Flywheel Core requests accrued rewards for a specific gauge:
 *  1. All prior rewards before this cycle are distributed
 *  2. Rewards for the current cycle are distributed proportionally to the remaining time in the cycle.
 *     If `e` is the cycle end, `t` is the min of e and current timestamp, and `p` is the prior updated time:
 *     For `A` accrued rewards over the cycle, distribute `min(A * (t-p)/(e-p), A)`.
 */
interface IFlywheelGaugeRewards {
    /// @notice rewards queued from prior and current cycles
    struct QueuedRewards {
        uint112 priorCycleRewards;
        uint112 cycleRewards;
        uint32 storedCycle;
    }

    /*//////////////////////////////////////////////////////////////
                        REWARDS CONTRACT STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice the gauge token for determining gauge allocations of the rewards stream
    function gaugeToken() external view returns (ERC20Gauges);

    /// @notice the rewards token for this flywheel rewards contract
    function rewardToken() external view returns (address);

    /// @notice the start of the current cycle
    function gaugeCycle() external view returns (uint32);

    /// @notice the length of a gauge/rewards cycle
    function gaugeCycleLength() external view returns (uint32);

    /// @notice mapping from gauges to queued rewards
    function gaugeQueuedRewards(ERC20)
        external
        view
        returns (uint112 priorCycleRewards, uint112 cycleRewards, uint32 storedCycle);

    /*//////////////////////////////////////////////////////////////
                        GAUGE REWARDS LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Iterates over all live gauges and queues up the rewards for the cycle
     * @return totalQueuedForCycle the max amount of rewards to be distributed over the cycle
     */
    function queueRewardsForCycle() external returns (uint256 totalQueuedForCycle);

    /// @notice Iterates over all live gauges and queues up the rewards for the cycle
    function queueRewardsForCyclePaginated(uint256 numRewards) external;

    /*//////////////////////////////////////////////////////////////
                        FLYWHEEL CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice calculate and transfer accrued rewards to flywheel core
     *  @dev msg.sender is the gauge to accrue rewards for
     * @return amount amounts of tokens accrued and transferred
     */
    function getAccruedRewards() external returns (uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice emitted when a cycle has completely queued and started
    event CycleStart(uint32 indexed cycleStart, uint256 rewardAmount);

    /// @notice emitted when a single gauge is queued. May be emitted before the cycle starts if the queue is done via pagination.
    event QueueRewards(address indexed gauge, uint32 indexed cycleStart, uint256 rewardAmount);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice thrown when trying to queue a new cycle during an old one.
    error CycleError();

    /// @notice thrown when trying to queue with 0 gauges
    error EmptyGaugesError();
}
