// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {WETH9} from "../interfaces/IWETH9.sol";

import {IAnycallProxy} from "../interfaces/IAnycallProxy.sol";
import {IRootBridgeAgent} from "../interfaces/IRootBridgeAgent.sol";
import {IRootBridgeAgentFactory} from "../interfaces/IRootBridgeAgentFactory.sol";
import {IRootPort} from "../interfaces/IRootPort.sol";

import {DeployRootBridgeAgent, RootBridgeAgent} from "../RootBridgeAgent.sol";

/// @title Root Bridge Agent Factory Contract
contract RootBridgeAgentFactory is IRootBridgeAgentFactory {
    /// @notice Root Chain Id
    uint24 public immutable rootChainId;

    /// @notice Local Wrapped Native Token
    WETH9 public immutable wrappedNativeToken;

    /// @notice Root Port Address
    address public immutable rootPortAddress;

    /// @notice DAO Address
    address public immutable daoAddress;

    /// @notice Local Anycall Address
    address public immutable localAnyCallAddress;

    /// @notice Local Anyexec Address
    address public immutable localAnyCallExecutorAddress;

    /// @notice Bridge Agent Manager
    mapping(address => address) public getBridgeAgentManager;

    /**
     * @notice Constructor for Bridge Agent.
     *     @param _rootChainId Root Chain Id.
     *     @param _wrappedNativeToken Local Wrapped Native Token.
     *     @param _localAnyCallAddress Local Anycall Address.
     *     @param _rootPortAddress Local Port Address.
     *     @param _daoAddress DAO Address.
     */
    constructor(
        uint24 _rootChainId,
        WETH9 _wrappedNativeToken,
        address _localAnyCallAddress,
        address _rootPortAddress,
        address _daoAddress
    ) {
        require(address(_wrappedNativeToken) != address(0), "Wrapped Native Token cannot be 0");
        require(_rootPortAddress != address(0), "Root Port Address cannot be 0");
        require(_daoAddress != address(0), "DAO Address cannot be 0");

        rootChainId = _rootChainId;
        wrappedNativeToken = _wrappedNativeToken;
        localAnyCallAddress = _localAnyCallAddress;
        localAnyCallExecutorAddress = IAnycallProxy(localAnyCallAddress).executor();
        rootPortAddress = _rootPortAddress;
        daoAddress = _daoAddress;
    }

    /*///////////////////////////////////////////////////////////////
                        BRIDGE AGENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Creates a new Root Bridge Agent.
     *   @param _newRootRouterAddress New Root Router Address.
     *   @return newBridgeAgent New Bridge Agent Address.
     */
    function createBridgeAgent(address _newRootRouterAddress) external returns (address newBridgeAgent) {
        newBridgeAgent = address(
            DeployRootBridgeAgent.deploy(
                wrappedNativeToken,
                rootChainId,
                daoAddress,
                localAnyCallAddress,
                localAnyCallExecutorAddress,
                rootPortAddress,
                _newRootRouterAddress
            )
        );

        IRootPort(rootPortAddress).addBridgeAgent(msg.sender, newBridgeAgent);
    }
}
