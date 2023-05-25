// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title  Core Branch Router Contract
 * @author MaiaDAO
 * @notice Core Branch Router implementation for deployment in Branch Chains.
 *         This contract is allows users to permissionlessly add new tokens
 *         or Bridge Agents to the system. As well as executes key governance
 *         enabled system functions (i.e. `addBridgeAgentFactory`).
 * @dev    Func IDs for calling these functions through messaging layer:
 *
 *         CROSS-CHAIN MESSAGING FUNCIDs
 *         -----------------------------
 *         FUNC ID      | FUNC NAME
 *         -------------+---------------
 *         0x01         | addGlobalToken
 *         0x02         | addBridgeAgent
 *         0x03         | toggleBranchBridgeAgentFactory
 *         0x04         | removeBranchBridgeAgent
 *         0x05         | manageStrategyToken
 *         0x06         | managePortStrategy
 *
 */
interface ICoreBranchRouter {
    /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to deploy/add a token already present in the global environment to a branch chain.
     * @param _globalAddress the address of the global virtualized token.
     * @param _toChain the chain to which the token will be added.
     * @param _remoteExecutionGas the amount of gas to be sent to the remote chain.
     * @param _rootExecutionGas the amount of gas to be sent to the root chain.
     */
    function addGlobalToken(
        address _globalAddress,
        uint256 _toChain,
        uint128 _remoteExecutionGas,
        uint128 _rootExecutionGas
    ) external payable;

    /**
     * @notice Function to add a token that's not available in the global environment from this branch chain.
     * @param _underlyingAddress the address of the token to be added.
     */
    function addLocalToken(address _underlyingAddress) external payable;

    /**
     * @notice Function to link a new bridge agent to the root bridge agent (which resides in Arbitrum).
     * @param _newBridgeAgentAddress the address of the new local bridge agent.
     * @param _rootBridgeAgentAddress the address of the root bridge agent.
     */
    function syncBridgeAgent(address _newBridgeAgentAddress, address _rootBridgeAgentAddress) external payable;
}
