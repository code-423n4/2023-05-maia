// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {IBranchRouter} from "./interfaces/IBranchRouter.sol";

import {
    IBranchBridgeAgent as IBridgeAgent,
    Deposit,
    DepositStatus,
    DepositInput,
    DepositParams,
    DepositMultipleInput,
    DepositMultipleParams,
    SettlementParams,
    SettlementMultipleParams
} from "./interfaces/IBranchBridgeAgent.sol";

/// @title Base Branch Router Contract
contract BaseBranchRouter is IBranchRouter, Ownable {
    /// @inheritdoc IBranchRouter
    address public localBridgeAgentAddress;

    /// @inheritdoc IBranchRouter
    address public bridgeAgentExecutorAddress;

    constructor() {
        _initializeOwner(msg.sender);
    }

    /*///////////////////////////////////////////////////////////////
                        OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Contract state initialization function.
    function initialize(address _localBridgeAgentAddress) external onlyOwner {
        require(_localBridgeAgentAddress != address(0), "Bridge Agent address cannot be 0");
        localBridgeAgentAddress = _localBridgeAgentAddress;
        bridgeAgentExecutorAddress = IBridgeAgent(localBridgeAgentAddress).bridgeAgentExecutorAddress();
        renounceOwnership();
    }

    /*///////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBranchRouter
    function getDepositEntry(uint32 _depositNonce) external view returns (Deposit memory) {
        return IBridgeAgent(localBridgeAgentAddress).getDepositEntry(_depositNonce);
    }

    /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBranchRouter
    function callOut(bytes calldata params, uint128 remoteExecutionGas) external payable lock {
        IBridgeAgent(localBridgeAgentAddress).performCallOut{value: msg.value}(
            msg.sender, params, 0, remoteExecutionGas
        );
    }

    /// @inheritdoc IBranchRouter
    function callOutAndBridge(bytes calldata params, DepositInput memory dParams, uint128 remoteExecutionGas)
        external
        payable
        lock
    {
        IBridgeAgent(localBridgeAgentAddress).performCallOutAndBridge{value: msg.value}(
            msg.sender, params, dParams, 0, remoteExecutionGas
        );
    }

    /// @inheritdoc IBranchRouter
    function callOutAndBridgeMultiple(
        bytes calldata params,
        DepositMultipleInput memory dParams,
        uint128 remoteExecutionGas
    ) external payable lock {
        IBridgeAgent(localBridgeAgentAddress).performCallOutAndBridgeMultiple{value: msg.value}(
            msg.sender, params, dParams, 0, remoteExecutionGas
        );
    }

    /// @inheritdoc IBranchRouter
    function retrySettlement(uint32 _settlementNonce, uint128 _gasToBoostSettlement) external payable lock {
        IBridgeAgent(localBridgeAgentAddress).retrySettlement{value: msg.value}(_settlementNonce, _gasToBoostSettlement);
    }

    /// @inheritdoc IBranchRouter
    function redeemDeposit(uint32 _depositNonce) external lock {
        IBridgeAgent(localBridgeAgentAddress).redeemDeposit(_depositNonce);
    }

    /*///////////////////////////////////////////////////////////////
                        ANYCALL EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBranchRouter
    function anyExecuteNoSettlement(bytes calldata)
        external
        virtual
        requiresAgentExecutor
        returns (bool success, bytes memory result)
    {
        /// Unrecognized Function Selector
        return (false, "unknown selector");
    }

    /// @inheritdoc IBranchRouter
    function anyExecuteSettlement(bytes calldata, SettlementParams memory)
        external
        virtual
        requiresAgentExecutor
        returns (bool success, bytes memory result)
    {
        /// Unrecognized Function Selector
        return (false, "unknown selector");
    }

    /// @inheritdoc IBranchRouter
    function anyExecuteSettlementMultiple(bytes calldata, SettlementMultipleParams memory)
        external
        virtual
        requiresAgentExecutor
        returns (bool success, bytes memory result)
    {
        /// Unrecognized Function Selector
        return (false, "unknown selector");
    }

    /*///////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Modifier that verifies msg sender is the Bridge Agent Executor.
    modifier requiresAgentExecutor() {
        if (msg.sender != bridgeAgentExecutorAddress) revert UnrecognizedBridgeAgentExecutor();
        _;
    }

    uint256 internal _unlocked = 1;

    /// @notice Modifier for a simple re-entrancy check.
    modifier lock() {
        require(_unlocked == 1);
        _unlocked = 2;
        _;
        _unlocked = 1;
    }
}
