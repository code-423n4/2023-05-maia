// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.10;

/// IApp interface of the application
interface IApp {
    /**
     * @notice anyExecute is the function that will be called on the destination chain to execute interaction (required).
     *     @param _data interaction arguments to exec on the destination chain.
     *     @return success whether the interaction was successful.
     *     @return result the result of the interaction.
     */
    function anyExecute(bytes calldata _data) external returns (bool success, bytes memory result);

    /**
     * @notice anyFallback is the function that will be called on the originating chain if the cross chain interaction fails (optional, advised).
     *     @param _data interaction arguments to exec on the destination chain.
     *     @return success whether the interaction was successful.
     *     @return result the result of the interaction.
     */
    function anyFallback(bytes calldata _data) external returns (bool success, bytes memory result);
}
