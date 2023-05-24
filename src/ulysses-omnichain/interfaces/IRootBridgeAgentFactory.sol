// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title  Root Bridge Agent Factory Contract
 * @author MaiaDAO
 * @notice Factory contract used to deploy new Root Bridge Agents responsible
 *         which are in charge of managing the deposit and withdrawal of assets
 *         between the branch chains and the omnichain environment.
 */
interface IRootBridgeAgentFactory {
    /*///////////////////////////////////////////////////////////////
                        BRIDGE AGENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createBridgeAgent(address newRootRouterAddress) external returns (address newBridgeAgent);
}
