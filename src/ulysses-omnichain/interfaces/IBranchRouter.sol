// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
    Deposit,
    DepositInput,
    DepositMultipleInput,
    SettlementParams,
    SettlementMultipleParams
} from "./IBranchBridgeAgent.sol";

/**
 * @title  BaseBranchRouter Contract
 * @author MaiaDAO
 * @notice Base Branch Contract for interfacing with Branch Bridge Agents.
 *         This contract for deployment in Branch Chains of the Ulysses Omnichain System,
 *         additional logic can be implemented to perform actions before sending cross-chain
 *         requests, as well as in response to requests from the Root Omnichain Environment.
 */
interface IBranchRouter {
    /*///////////////////////////////////////////////////////////////
                            VIEW / STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Address for local Branch Bridge Agent who processes requests and ineracts with local port.
    function localBridgeAgentAddress() external view returns (address);

    /// @notice Local Bridge Agent Executor Address.
    function bridgeAgentExecutorAddress() external view returns (address);

    /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to perform a call to the Root Omnichain Router without token deposit.
     *   @param params RLP enconded parameters to execute on the root chain.
     *   @param rootExecutionGas gas allocated for remote execution.
     *   @dev ACTION ID: 1 (Call without deposit)
     *
     */
    function callOut(bytes calldata params, uint128 rootExecutionGas) external payable;

    /**
     * @notice Function to perform a call to the Root Omnichain Router while depositing a single asset.
     *   @param params RLP enconded parameters to execute on the root chain.
     *   @param dParams additional token deposit parameters.
     *   @param rootExecutionGas gas allocated for remote execution.
     *   @dev ACTION ID: 2 (Call with single deposit)
     *
     */
    function callOutAndBridge(bytes calldata params, DepositInput memory dParams, uint128 rootExecutionGas)
        external
        payable;

    /**
     * @notice Function to perform a call to the Root Omnichain Router while depositing two or more assets.
     *   @param params RLP enconded parameters to execute on the root chain.
     *   @param dParams additional token deposit parameters.
     *   @param rootExecutionGas gas allocated for remote execution.
     *   @dev ACTION ID: 3 (Call with multiple deposit)
     *
     */
    function callOutAndBridgeMultiple(
        bytes calldata params,
        DepositMultipleInput memory dParams,
        uint128 rootExecutionGas
    ) external payable;

    /**
     * @notice External function to retry a failed Settlement entry on the root chain.
     *     @param _settlementNonce Identifier for user settlement.
     *     @param _gasToBoostSettlement Additional gas to boost settlement.
     *
     */
    function retrySettlement(uint32 _settlementNonce, uint128 _gasToBoostSettlement) external payable;

    /**
     * @notice External function to retry a failed Deposit entry on this branch chain.
     *     @param _depositNonce Identifier for user deposit.
     *
     */
    function redeemDeposit(uint32 _depositNonce) external;

    /**
     * @notice External function that returns a given deposit entry.
     *     @param _depositNonce Identifier for user deposit.
     *
     */
    function getDepositEntry(uint32 _depositNonce) external view returns (Deposit memory);

    /*///////////////////////////////////////////////////////////////
                        ANYCALL EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function responsible of executing a branch router response.
     *     @param data data received from messaging layer.
     */
    function anyExecuteNoSettlement(bytes calldata data) external returns (bool success, bytes memory result);

    /**
     * @dev Function responsible of executing a crosschain request without any deposit.
     *     @param data data received from messaging layer.
     *     @param sParams SettlementParams struct.
     */
    function anyExecuteSettlement(bytes calldata data, SettlementParams memory sParams)
        external
        returns (bool success, bytes memory result);

    /**
     * @dev Function responsible of executing a crosschain request which contains cross-chain deposit information attached.
     *     @param data data received from messaging layer.
     *     @param sParams SettlementParams struct containing deposit information.
     *
     */
    function anyExecuteSettlementMultiple(bytes calldata data, SettlementMultipleParams memory sParams)
        external
        returns (bool success, bytes memory result);

    /*///////////////////////////////////////////////////////////////
                             ERRORS
    //////////////////////////////////////////////////////////////*/

    error UnrecognizedBridgeAgentExecutor();
}
