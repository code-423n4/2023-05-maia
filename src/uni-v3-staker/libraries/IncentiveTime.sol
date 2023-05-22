// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Incentive Time library
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice This library is responsible for computing the incentive start and end times.
 */
library IncentiveTime {
    /// @notice Throws when the staked timestamp is before the incentive start time.
    error InvalidStartTime();

    uint256 private constant INCENTIVES_DURATION = 1 weeks; // Incentives are 1 week long and start at THURSDAY 12:00:00 UTC (00:00:00 UTC + 12 hours (INCENTIVE_OFFSET))

    uint256 private constant INCENTIVES_OFFSET = 12 hours;

    function computeStart(uint256 timestamp) internal pure returns (uint96 start) {
        /// @dev The start of the incentive is the start of the week (Thursday 12:00:00 UTC) that the timestamp falls in
        /// Remove Offset, rounds down to nearest week, adds offset back
        return uint96(((timestamp - INCENTIVES_OFFSET) / INCENTIVES_DURATION) * INCENTIVES_DURATION + INCENTIVES_OFFSET);
    }

    function computeEnd(uint256 timestamp) internal pure returns (uint96 end) {
        /// @dev The end of the incentive is the end of the week (Thursday 12:00:00 UTC) that the timestamp falls in
        /// Remove Offset, rounds up to nearest week, adds offset back
        return uint96(
            (((timestamp - INCENTIVES_OFFSET) / INCENTIVES_DURATION) + 1) * INCENTIVES_DURATION + INCENTIVES_OFFSET
        );
    }

    function getEnd(uint96 start) internal pure returns (uint96 end) {
        end = start + uint96(INCENTIVES_DURATION);
    }

    function getEndAndDuration(uint96 start, uint40 stakedTimestamp, uint256 timestamp)
        internal
        pure
        returns (uint96 end, uint256 stakedDuration)
    {
        if (stakedTimestamp < start) revert InvalidStartTime();
        end = start + uint96(INCENTIVES_DURATION);

        // get earliest, block.timestamp or endTime
        uint256 earliest = timestamp < end ? timestamp : end;

        stakedDuration = earliest - stakedTimestamp;
    }
}
