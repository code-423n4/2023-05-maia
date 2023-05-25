// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// Rewards logic inspired by Uniswap V3 Contracts (Uniswap/v3-staker/contracts/libraries/RewardMath.sol)

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

/// @title Math for computing rewards for Uniswap V3 LPs with boost
/// @notice Allows computing rewards given some parameters of boost, stakes and incentives
library RewardMath {
    using FixedPointMathLib for uint256;

    /// @notice Compute the amount of rewards owed given parameters of the incentive and stake
    /// @param stakedDuration The duration staked or 1 week if larger than 1 week
    /// @param liquidity The amount of liquidity, assumed to be constant over the period over which the snapshots are measured
    /// @param boostAmount The amount of boost tokens staked
    /// @param boostTotalSupply The total amount of boost tokens staked
    /// @param secondsPerLiquidityInsideInitialX128 The seconds per liquidity of the liquidity tick range as of the beginning of the period
    /// @param secondsPerLiquidityInsideX128 The seconds per liquidity of the liquidity tick range as of the current block timestamp
    /// @return boostedSecondsInsideX128 The total liquidity seconds inside the position's range for the duration of the stake, adjusted to account for boost
    function computeBoostedSecondsInsideX128(
        uint256 stakedDuration,
        uint128 liquidity,
        uint128 boostAmount,
        uint128 boostTotalSupply,
        uint160 secondsPerLiquidityInsideInitialX128,
        uint160 secondsPerLiquidityInsideX128
    ) internal pure returns (uint160 boostedSecondsInsideX128) {
        // this operation is safe, as the difference cannot be greater than 1/stake.liquidity
        uint160 secondsInsideX128 = (secondsPerLiquidityInsideX128 - secondsPerLiquidityInsideInitialX128) * liquidity;

        if (boostTotalSupply > 0) {
            // calculate boosted seconds insisde
            // 40% of original value + 60% of ((staked duration * boost amount) / boost total supply)
            boostedSecondsInsideX128 = uint160(
                ((secondsInsideX128 * 4) / 10) + ((((stakedDuration << 128) * boostAmount) / boostTotalSupply) * 6) / 10
            );

            // calculate boosted seconds inside, can't be larger than the original reward amount
            if (boostedSecondsInsideX128 > secondsInsideX128) {
                boostedSecondsInsideX128 = secondsInsideX128;
            }
        } else {
            // if no boost supply, then just use 40% of original value
            boostedSecondsInsideX128 = (secondsInsideX128 * 4) / 10;
        }
    }

    /// @notice Compute the amount of rewards owed given parameters of the incentive and stake
    /// @param totalRewardUnclaimed The total amount of unclaimed rewards left for an incentive
    /// @param totalSecondsClaimedX128 How many full liquidity seconds have been already claimed for the incentive
    /// @param startTime When the incentive rewards began in epoch seconds
    /// @param endTime When rewards are no longer being dripped out in epoch seconds
    /// @param secondsInsideX128 The total liquidity seconds inside the position's range for the duration of the stake
    /// @param currentTime The current block timestamp, which must be greater than or equal to the start time
    /// @return reward The amount of rewards owed
    function computeBoostedRewardAmount(
        uint256 totalRewardUnclaimed,
        uint160 totalSecondsClaimedX128,
        uint256 startTime,
        uint256 endTime,
        uint160 secondsInsideX128,
        uint256 currentTime
    ) internal pure returns (uint256) {
        // this should never be called before the start time
        assert(currentTime >= startTime);

        uint256 totalSecondsUnclaimedX128 = ((endTime.max(currentTime) - startTime) << 128) - totalSecondsClaimedX128;

        return totalRewardUnclaimed.mulDiv(secondsInsideX128, totalSecondsUnclaimedX128);
    }
}
