// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {IBranchPort as IPort} from "./interfaces/IBranchPort.sol";
import {IBranchBridgeAgent as IBridgeAgent} from "./interfaces/IBranchBridgeAgent.sol";
import {IBranchBridgeAgentFactory as IBridgeAgentFactory} from "./interfaces/IBranchBridgeAgentFactory.sol";
import {IBranchRouter} from "./interfaces/IBranchRouter.sol";
import {ICoreBranchRouter} from "./interfaces/ICoreBranchRouter.sol";
import {IERC20hTokenBranchFactory as ITokenFactory} from "./interfaces/IERC20hTokenBranchFactory.sol";

import {BaseBranchRouter} from "./BaseBranchRouter.sol";
import {ERC20hTokenBranch as ERC20hToken} from "./token/ERC20hTokenBranch.sol";

/// @title Core Branch Router Contract
contract CoreBranchRouter is BaseBranchRouter {
    /// @notice hToken Factory Address.
    address public hTokenFactoryAddress;

    /// @notice Local Port Address.
    address public localPortAddress;

    constructor(address _hTokenFactoryAddress, address _localPortAddress) BaseBranchRouter() {
        localPortAddress = _localPortAddress;
        hTokenFactoryAddress = _hTokenFactoryAddress;
    }

    /*///////////////////////////////////////////////////////////////
                 TOKEN MANAGEMENT EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice This function is used to add a global token to a branch.
     * @param _globalAddress Address of the token to be added.
     * @param _toChain Chain Id of the chain to which the deposit is being added.
     * @param _remoteExecutionGas Gas to be used for the remote execution in destination chain.
     * @param _rootExecutionGas Gas to be saved for the final root execution.
     */
    function addGlobalToken(
        address _globalAddress,
        uint24 _toChain,
        uint128 _remoteExecutionGas,
        uint128 _rootExecutionGas
    ) external payable {
        //Encode Call Data
        bytes memory data = abi.encode(msg.sender, _globalAddress, _toChain, _rootExecutionGas);

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x01), data);

        //Send Cross-Chain request (System Response/Request)
        IBridgeAgent(localBridgeAgentAddress).performCallOut{value: msg.value}(
            msg.sender, packedData, 0, _remoteExecutionGas
        );
    }

    /**
     * @notice This function is used to add a local token to the system.
     * @param _underlyingAddress Address of the underlying token to be added.
     */
    function addLocalToken(address _underlyingAddress) external payable virtual {
        //Get Token Info
        string memory name = ERC20(_underlyingAddress).name();
        string memory symbol = ERC20(_underlyingAddress).symbol();

        //Create Token
        ERC20hToken newToken = ITokenFactory(hTokenFactoryAddress).createToken(name, symbol);

        //Encode Data
        bytes memory data = abi.encode(_underlyingAddress, newToken, name, symbol);

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x02), data);

        //Send Cross-Chain request (System Response/Request)
        IBridgeAgent(localBridgeAgentAddress).performCallOut{value: msg.value}(msg.sender, packedData, 0, 0);
    }

    /*///////////////////////////////////////////////////////////////
                 TOKEN MANAGEMENT INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to deploy/add a token already active in the global environment in the Root Chain. Must be called from another chain.
     *  @param _globalAddress the address of the global virtualized token.
     *  @param _name token name.
     *  @param _symbol token symbol.
     *  @param _rootExecutionGas the amount of gas to be used in the root execution.
     *  @dev FUNC ID: 1
     *  @dev all hTokens have 18 decimals.
     *
     */
    function _receiveAddGlobalToken(
        address _globalAddress,
        string memory _name,
        string memory _symbol,
        uint128 _rootExecutionGas
    ) internal {
        //Create Token
        ERC20hToken newToken = ITokenFactory(hTokenFactoryAddress).createToken(_name, _symbol);

        //Encode Data
        bytes memory data = abi.encode(_globalAddress, newToken);

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x03), data);

        //Send Cross-Chain request
        IBridgeAgent(localBridgeAgentAddress).performSystemCallOut(address(this), packedData, _rootExecutionGas, 0);
    }

    /**
     * @notice Function to deploy/add a token already active in the global environment in the Root Chain. Must be called from another chain.
     *  @param _newBranchRouter the address of the new branch router.
     *  @param _branchBridgeAgentFactory the address of the branch bridge agent factory.
     *  @param _rootBridgeAgent the address of the root bridge agent.
     *  @param _rootBridgeAgentFactory the address of the root bridge agent factory.
     *  @param _remoteExecutionGas the amount of gas to be used in the remote execution.
     *  @dev FUNC ID: 2
     *  @dev all hTokens have 18 decimals.
     *
     */
    function _receiveAddBridgeAgent(
        address _newBranchRouter,
        address _branchBridgeAgentFactory,
        address _rootBridgeAgent,
        address _rootBridgeAgentFactory,
        uint128 _remoteExecutionGas
    ) internal virtual {
        //Check if msg.sender is a valid BridgeAgentFactory
        if (!IPort(localPortAddress).isBridgeAgentFactory(_branchBridgeAgentFactory)) {
            revert UnrecognizedBridgeAgentFactory();
        }

        //Create Token
        address newBridgeAgent = IBridgeAgentFactory(_branchBridgeAgentFactory).createBridgeAgent(
            _newBranchRouter, _rootBridgeAgent, _rootBridgeAgentFactory
        );

        //Check BridgeAgent Address
        if (!IPort(localPortAddress).isBridgeAgent(newBridgeAgent)) {
            revert UnrecognizedBridgeAgent();
        }

        //Encode Data
        bytes memory data = abi.encode(newBridgeAgent, _rootBridgeAgent);

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x04), data);

        //Send Cross-Chain request
        IBridgeAgent(localBridgeAgentAddress).performSystemCallOut(address(this), packedData, _remoteExecutionGas, 0);
    }

    /**
     * @notice Function to add/deactivate a Branch Bridge Agent Factory.
     *  @param _newBridgeAgentFactoryAddress the address of the new local bridge agent factory.
     *  @dev FUNC ID: 3
     *
     */
    function _toggleBranchBridgeAgentFactory(address _newBridgeAgentFactoryAddress) internal {
        if (!IPort(localPortAddress).isBridgeAgentFactory(_newBridgeAgentFactoryAddress)) {
            IPort(localPortAddress).addBridgeAgentFactory(_newBridgeAgentFactoryAddress);
        } else {
            IPort(localPortAddress).toggleBridgeAgentFactory(_newBridgeAgentFactoryAddress);
        }
    }

    /**
     * @notice Function to remove an active Branch Bridge Agent from the system.
     *  @param _branchBridgeAgent the address of the local Bridge Agent to be removed.
     *  @dev FUNC ID: 4
     *
     */
    function _removeBranchBridgeAgent(address _branchBridgeAgent) internal {
        if (!IPort(localPortAddress).isBridgeAgent(_branchBridgeAgent)) revert UnrecognizedBridgeAgent();
        IPort(localPortAddress).toggleBridgeAgent(_branchBridgeAgent);
    }

    /**
     * @notice Function to add / remove a token to be used by Port Strategies.
     *  @param _underlyingToken the address of the underlying token.
     *  @param _minimumReservesRatio the minimum reserves ratio the Port must have.
     *  @dev FUNC ID: 5
     *
     */
    function _manageStrategyToken(address _underlyingToken, uint256 _minimumReservesRatio) internal {
        if (!IPort(localPortAddress).isStrategyToken(_underlyingToken)) {
            IPort(localPortAddress).addStrategyToken(_underlyingToken, _minimumReservesRatio);
        } else {
            IPort(localPortAddress).toggleStrategyToken(_underlyingToken);
        }
    }

    /**
     * @notice Function to deploy/add a token already active in the global enviornment in the Root Chain. Must be called from another chain.
     *  @param _portStrategy the address of the port strategy.
     *  @param _underlyingToken the address of the underlying token.
     *  @param _dailyManagementLimit the daily management limit.
     *  @param _isUpdateDailyLimit if the daily limit is being updated.
     *  @dev FUNC ID: 6
     *
     */
    function _managePortStrategy(
        address _portStrategy,
        address _underlyingToken,
        uint256 _dailyManagementLimit,
        bool _isUpdateDailyLimit
    ) internal {
        if (!IPort(localPortAddress).isPortStrategy(_portStrategy, _underlyingToken)) {
            //Add new Port Strategy if new.
            IPort(localPortAddress).addPortStrategy(_portStrategy, _underlyingToken, _dailyManagementLimit);
        } else if (_isUpdateDailyLimit) {
            //Or Update daily limit.
            IPort(localPortAddress).updatePortStrategy(_portStrategy, _underlyingToken, _dailyManagementLimit);
        } else {
            //Or Toggle Port Strategy.
            IPort(localPortAddress).togglePortStrategy(_portStrategy, _underlyingToken);
        }
    }

    /*///////////////////////////////////////////////////////////////
                    ANYCALL EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBranchRouter
    function anyExecuteNoSettlement(bytes calldata _data)
        external
        virtual
        override
        requiresAgentExecutor
        returns (bool success, bytes memory result)
    {
        /// _receiveAddGlobalToken
        if (_data[0] == 0x01) {
            (address globalAddress, string memory name, string memory symbol, uint128 gasToBridgeOut) =
                abi.decode(_data[1:], (address, string, string, uint128));

            _receiveAddGlobalToken(globalAddress, name, symbol, gasToBridgeOut);
            /// _receiveAddBridgeAgent
        } else if (_data[0] == 0x02) {
            (
                address newBranchRouter,
                address branchBridgeAgentFactory,
                address rootBridgeAgent,
                address rootBridgeAgentFactory,
                uint128 remoteExecutionGas
            ) = abi.decode(_data[1:], (address, address, address, address, uint128));

            _receiveAddBridgeAgent(
                newBranchRouter, branchBridgeAgentFactory, rootBridgeAgent, rootBridgeAgentFactory, remoteExecutionGas
            );

            /// _toggleBranchBridgeAgentFactory
        } else if (_data[0] == 0x03) {
            (address bridgeAgentFactoryAddress) = abi.decode(_data[1:], (address));
            _toggleBranchBridgeAgentFactory(bridgeAgentFactoryAddress);

            /// _removeBranchBridgeAgent
        } else if (_data[0] == 0x04) {
            (address branchBridgeAgent) = abi.decode(_data[1:], (address));
            _removeBranchBridgeAgent(branchBridgeAgent);

            /// _manageStrategyToken
        } else if (_data[0] == 0x05) {
            (address underlyingToken, uint256 minimumReservesRatio) = abi.decode(_data[1:], (address, uint256));
            _manageStrategyToken(underlyingToken, minimumReservesRatio);

            /// _managePortStrategy
        } else if (_data[0] == 0x06) {
            (address portStrategy, address underlyingToken, uint256 dailyManagementLimit, bool isUpdateDailyLimit) =
                abi.decode(_data[1:], (address, address, uint256, bool));
            _managePortStrategy(portStrategy, underlyingToken, dailyManagementLimit, isUpdateDailyLimit);

            /// Unrecognized Function Selector
        } else {
            return (false, "unknown selector");
        }
        return (true, "");
    }

    fallback() external payable {}

    error UnrecognizedBridgeAgent();
    error UnrecognizedBridgeAgentFactory();
}
