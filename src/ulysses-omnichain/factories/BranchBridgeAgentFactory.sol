// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {WETH9} from "../interfaces/IWETH9.sol";

import {CoreBranchRouter} from "../CoreBranchRouter.sol";
import {BranchBridgeAgent, DeployBranchBridgeAgent} from "../BranchBridgeAgent.sol";

import {IAnycallProxy} from "../interfaces/IAnycallProxy.sol";
import {IBranchPort as IPort} from "../interfaces/IBranchPort.sol";
import {IBranchBridgeAgentFactory} from "../interfaces/IBranchBridgeAgentFactory.sol";

/// @title Branch Bridge Agent Factory Contract
contract BranchBridgeAgentFactory is Ownable, IBranchBridgeAgentFactory {
    /// @notice Local Chain Id
    uint256 public immutable localChainId;

    /// @notice Root Chain Id
    uint256 public immutable rootChainId;

    /// @notice Root Bridge Agent Factory Address
    address public immutable rootBridgeAgentFactoryAddress;

    /// @notice Local Wrapped Native Token
    WETH9 public immutable wrappedNativeToken;

    /// @notice Local Core Branch Router Address.
    address public immutable localCoreBranchRouterAddress;

    /// @notice Root Port Address
    address public immutable localPortAddress;

    /// @notice Local Anycall Address
    address public immutable localAnyCallAddress;

    /// @notice Local Anyexec Address
    address public immutable localAnyCallExecutorAddress;

    /**
     * @notice Constructor for Bridge Agent.
     *     @param _localChainId Local Chain Id.
     *     @param _rootChainId Root Chain Id.
     *     @param _rootBridgeAgentFactoryAddress Root Bridge Agent Factory Address.
     *     @param _wrappedNativeToken Local Wrapped Native Token.
     *     @param _localAnyCallAddress Local Anycall Address.
     *     @param _localAnyCallExecutorAddress Local Anyexec Address.
     *     @param _localCoreBranchRouterAddress Local Core Branch Router Address.
     *     @param _localPortAddress Local Port Address.
     *     @param _owner Owner of the contract.
     */
    constructor(
        uint256 _localChainId,
        uint256 _rootChainId,
        address _rootBridgeAgentFactoryAddress,
        WETH9 _wrappedNativeToken,
        address _localAnyCallAddress,
        address _localAnyCallExecutorAddress,
        address _localCoreBranchRouterAddress,
        address _localPortAddress,
        address _owner
    ) {
        require(_rootBridgeAgentFactoryAddress != address(0), "Root Bridge Agent Factory Address cannot be 0");
        require(address(_wrappedNativeToken) != address(0), "Wrapped Native Token cannot be 0");
        require(_localAnyCallAddress != address(0), "Anycall Address cannot be 0");
        require(_localAnyCallExecutorAddress != address(0), "Anyexec Address cannot be 0");
        require(_localCoreBranchRouterAddress != address(0), "Core Branch Router Address cannot be 0");
        require(_localPortAddress != address(0), "Port Address cannot be 0");
        require(_owner != address(0), "Owner cannot be 0");

        localChainId = _localChainId;
        rootChainId = _rootChainId;
        rootBridgeAgentFactoryAddress = _rootBridgeAgentFactoryAddress;
        wrappedNativeToken = _wrappedNativeToken;
        localAnyCallAddress = _localAnyCallAddress;
        localAnyCallExecutorAddress = _localAnyCallExecutorAddress;
        localCoreBranchRouterAddress = _localCoreBranchRouterAddress;
        localPortAddress = _localPortAddress;
        _initializeOwner(_owner);
    }

    function initialize(address _coreRootBridgeAgent) external virtual onlyOwner {
        require(_coreRootBridgeAgent != address(0), "Core Root Bridge Agent cannot be 0");

        address newCoreBridgeAgent = address(
            DeployBranchBridgeAgent.deploy(
                wrappedNativeToken,
                rootChainId,
                localChainId,
                _coreRootBridgeAgent,
                localAnyCallAddress,
                localAnyCallExecutorAddress,
                localCoreBranchRouterAddress,
                localPortAddress
            )
        );

        IPort(localPortAddress).addBridgeAgent(newCoreBridgeAgent);

        renounceOwnership();
    }

    /*///////////////////////////////////////////////////////////////
                        BRIDGE AGENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new bridge agent for a new branch chain.
     * @param _newBranchRouterAddress Address of the new branch router.
     * @param _rootBridgeAgentAddress Address of the root bridge agent.
     */
    function createBridgeAgent(
        address _newBranchRouterAddress,
        address _rootBridgeAgentAddress,
        address _rootBridgeAgentFactoryAddress
    ) external virtual returns (address newBridgeAgent) {
        require(
            msg.sender == localCoreBranchRouterAddress, "Only the Core Branch Router can create a new Bridge Agent."
        );
        require(
            _rootBridgeAgentFactoryAddress == rootBridgeAgentFactoryAddress,
            "Root Bridge Agent Factory Address does not match."
        );

        newBridgeAgent = address(
            DeployBranchBridgeAgent.deploy(
                wrappedNativeToken,
                rootChainId,
                localChainId,
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
