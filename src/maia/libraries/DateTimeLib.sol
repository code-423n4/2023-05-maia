// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title Library to check if it is the first Tuesday of a month.
/// @notice Library for date time operations.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/DateTimeLib.sol)
///
/// Conventions:
/// --------------------------------------------------------------------+
/// Unit      | Range                | Notes                            |
/// --------------------------------------------------------------------|
/// timestamp | 0..0x1e18549868c76ff | Unix timestamp.                  |
/// epochDay  | 0..0x16d3e098039     | Days since 1970-01-01.           |
/// year      | 1970..0xffffffff     | Gregorian calendar year.         |
/// month     | 1..12                | Gregorian calendar month.        |
/// day       | 1..31                | Gregorian calendar day of month. |
/// weekday   | 1..7                 | The day of the week (1-indexed). |
/// --------------------------------------------------------------------+
/// All timestamps of days are rounded down to 00:00:00 UTC.
library DateTimeLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Weekdays are 1-indexed for a traditional rustic feel.

    // "And on the seventh day God finished his work that he had done,
    // and he rested on the seventh day from all his work that he had done."
    // -- Genesis 2:2

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    DATE TIME OPERATIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns (`month`) from the number of days since 1970-01-01.
    /// See: https://howardhinnant.github.io/date_algorithms.html
    /// Note: Inputs outside the supported ranges result in undefined behavior.
    /// Use {isSupportedDays} to check if the inputs is supported.
    function getMonth(uint256 timestamp) internal pure returns (uint256 month) {
        uint256 epochDay = timestamp / 86400;

        /// @solidity memory-safe-assembly
        assembly {
            epochDay := add(epochDay, 719468)
            let doe := mod(epochDay, 146097)
            let yoe := div(sub(sub(add(doe, div(doe, 36524)), div(doe, 1460)), eq(doe, 146096)), 365)
            let doy := sub(doe, sub(add(mul(365, yoe), shr(2, yoe)), div(yoe, 100)))
            let mp := div(add(mul(5, doy), 2), 153)
            month := sub(add(mp, 3), mul(gt(mp, 9), 12))
        }
    }

    /// @dev Returns the weekday from the unix timestamp.
    /// Monday: 1, Tuesday: 2, ....., Sunday: 7.
    function isTuesday(uint256 timestamp) internal pure returns (bool result, uint256 startOfDay) {
        unchecked {
            uint256 day = timestamp / 86400;
            startOfDay = day * 86400;
            result = ((day + 3) % 7) + 1 == 2;
        }
    }
}
