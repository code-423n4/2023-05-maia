// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WETH9} from "../interfaces/IWETH9.sol";

import {IArbitrumBranchPort as IPort} from "../interfaces/IArbitrumBranchPort.sol";

import {BranchBridgeAgentFactory} from "./BranchBridgeAgentFactory.sol";
import {ArbitrumBranchBridgeAgent, DeployArbitrumBranchBridgeAgent} from "../ArbitrumBranchBridgeAgent.sol";

/**
 * @title  Arbitrum Branch Bridge Agent Factory Contract
 * @author MaiaDAO
 * @notice Factory contract for allowing permissionless deployment of
 *         new Arbitrum Branch Bridge Agents which are in charge of 
 *         managing the deposit and withdrawal of assets between the
 *         branch chains and the omnichain environment.
 */
contract ArbitrumBranchBridgeAgentFactory is BranchBridgeAgentFactory {
    /**
     * @notice Constructor for Bridge Agent.
     *  @param _rootChainId Local Chain Id.
     *  @param _rootBridgeAgentFactoryAddress Root Bridge Agent Factory Address.
     *  @param _wrappedNativeToken Local Wrapped Native Token.
     *  @param _localAnyCallAddress Local Anycall Address.
     *  @param _localAnyCallExecutorAddress Local Anyexec Address.
     *  @param _localCoreBranchRouterAddress Local Core Branch Router Address.
     *  @param _localPortAddress Local Port Address.
     *  @param _owner Owner of the contract.
     */
    constructor(
        uint256 _rootChainId,
        address _rootBridgeAgentFactoryAddress,
        WETH9 _wrappedNativeToken,
        address _localAnyCallAddress,
        address _localAnyCallExecutorAddress,
        address _localCoreBranchRouterAddress,
        address _localPortAddress,
        address _owner
    )
        BranchBridgeAgentFactory(
            _rootChainId,
            _rootChainId,
            _rootBridgeAgentFactoryAddress,
            _wrappedNativeToken,
            _localAnyCallAddress,
            _localAnyCallExecutorAddress,
            _localCoreBranchRouterAddress,
            _localPortAddress,
            _owner
        )
    {}

    function initialize(address _coreRootBridgeAgent) external override onlyOwner {
        address newCoreBridgeAgent = address(
            DeployArbitrumBranchBridgeAgent.deploy(
                wrappedNativeToken,
                rootChainId,
                _coreRootBridgeAgent,
                localAnyCallAddress,
                localAnyCallExecutorAddress,
                localCoreBranchRouterAddress,
                localPortAddress
            )
        );

        IPort(localPortAddress).addBridgeAgent(newCoreBridgeAgent);
    }

    /*///////////////////////////////////////////////////////////////
                        BRIDGE AGENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new bridge agent for a branch chain.
     * @param _newBranchRouterAddress Address of the new branch router.
     * @param _rootBridgeAgentAddress Address of the root bridge agent.
     */
    function createBridgeAgent(
        address _newBranchRouterAddress,
        address _rootBridgeAgentAddress,
        address _rootBridgeAgentFactoryAddress
    ) external virtual override returns (address newBridgeAgent) {
        require(
            msg.sender == localCoreBranchRouterAddress, "Only the Core Branch Router can create a new Bridge Agent."
        );
        require(
            _rootBridgeAgentFactoryAddress == rootBridgeAgentFactoryAddress,
            "Root Bridge Agent Factory Address does not match."
        );

        newBridgeAgent = address(
            DeployArbitrumBranchBridgeAgent.deploy(
                wrappedNativeToken,
                rootChainId,
                _rootBridgeAgentAddress,
                localAnyCallAddress,
                localAnyCallExecutorAddress,
                _newBranchRouterAddress,
                localPortAddress
            )
        );

        IPort(localPortAddress).addBridgeAgent(newBridgeAgent);
    }
}
