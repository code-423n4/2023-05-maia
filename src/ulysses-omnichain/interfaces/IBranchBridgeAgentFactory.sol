// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IBridgeAgentFactory.
 * @author MaiaDAO.
 * @notice This contract is used to interact with the Bridge Agent Factory responsible for deploying new Bridge Agents which are in charge of managing the deposit and withdrawal of assets between the branch chains and the omnichain environment.
 */
interface IBranchBridgeAgentFactory {
    /*///////////////////////////////////////////////////////////////
                        BRIDGE AGENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createBridgeAgent(
        address newRootRouterAddress,
        address rootBridgeAgentAddress,
        address _rootBridgeAgentFactoryAddress
    ) external returns (address newBridgeAgent);
}
