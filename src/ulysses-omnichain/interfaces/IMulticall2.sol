// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Multicall2 - Aggregate results from multiple read-only function calls
/// @author Michael Elliot <mike@makerdao.com>
/// @author Joshua Levine <joshua@makerdao.com>
/// @author Nick Johnson <arachnid@notdot.net>

interface IMulticall2 {
    struct Call {
        address target;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    function aggregate(Call[] memory calls) external returns (uint256 blockNumber, bytes[] memory returnData);
}
