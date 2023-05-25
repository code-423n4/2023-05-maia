// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {WETH9} from "./interfaces/IWETH9.sol";

import {AnycallFlags} from "./lib/AnycallFlags.sol";
import {IAnycallProxy} from "./interfaces/IAnycallProxy.sol";
import {IAnycallConfig} from "./interfaces/IAnycallConfig.sol";
import {IAnycallExecutor} from "./interfaces/IAnycallExecutor.sol";

import {ERC20hTokenBranch as ERC20hToken} from "./token/ERC20hTokenBranch.sol";
import {IBranchRouter as IRouter} from "./interfaces/IBranchRouter.sol";
import {IArbitrumBranchPort as IArbPort} from "./interfaces/IArbitrumBranchPort.sol";
import {IRootBridgeAgent} from "./interfaces/IRootBridgeAgent.sol";

import {
    IBranchBridgeAgent,
    IApp,
    Deposit,
    DepositStatus,
    DepositInput,
    DepositMultipleInput,
    DepositParams,
    DepositMultipleParams,
    SettlementParams,
    SettlementMultipleParams
} from "./interfaces/IBranchBridgeAgent.sol";

import {BranchBridgeAgent} from "./BranchBridgeAgent.sol";
import {BranchBridgeAgentExecutor, DeployBranchBridgeAgentExecutor} from "./BranchBridgeAgentExecutor.sol";

library DeployArbitrumBranchBridgeAgent {
    function deploy(
        WETH9 _wrappedNativeToken,
        uint256 _localChainId,
        address _daoAddress,
        address _localAnyCallAddress,
        address _localAnyCallExecutorAddress,
        address _localPortAddress,
        address _localRouterAddress
    ) external returns (ArbitrumBranchBridgeAgent) {
        return new ArbitrumBranchBridgeAgent(
            _wrappedNativeToken,
            _localChainId,
            _daoAddress,
            _localAnyCallAddress,
            _localAnyCallExecutorAddress,
            _localPortAddress,
            _localRouterAddress
        );
    }
}

/**
 * @title  Manages bridging transactions between root and Arbitrum branch
 * @author MaiaDAO
 * @notice This contract is used for interfacing with Users/Routers acting as a middleman
 *         to access Anycall cross-chain messaging and Port communication for asset management
 *         connecting Arbitrum Branch Chain contracts and the root omnichain environment.
 * @dev    Execution gas from remote interactions is managed by `RootBridgeAgent` contract.
 */
contract ArbitrumBranchBridgeAgent is BranchBridgeAgent {
    using SafeTransferLib for address;
    using SafeTransferLib for ERC20;

    constructor(
        WETH9 _wrappedNativeToken,
        uint256 _localChainId,
        address _rootBridgeAgentAddress,
        address _localAnyCallAddress,
        address _localAnyCallExecutorAddress,
        address _localRouterAddress,
        address _localPortAddress
    )
        BranchBridgeAgent(
            _wrappedNativeToken,
            _localChainId,
            _localChainId,
            _rootBridgeAgentAddress,
            _localAnyCallAddress,
            _localAnyCallExecutorAddress,
            _localRouterAddress,
            _localPortAddress
        )
    {}

    /*///////////////////////////////////////////////////////////////
                    LOCAL USER EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to deposit a single asset to the local Port.
     *   @param underlyingAddress address of the underlying asset to be deposited.
     *   @param amount amount to be deposited.
     *
     */
    function depositToPort(address underlyingAddress, uint256 amount) external payable lock {
        IArbPort(localPortAddress).depositToPort(
            msg.sender, msg.sender, underlyingAddress, _normalizeDecimals(amount, ERC20(underlyingAddress).decimals())
        );
    }

    /**
     * @notice Function to withdraw a single asset to the local Port.
     *   @param localAddress local hToken to be withdrawn.
     *   @param amount amount to be withdrawn.
     *
     */
    function withdrawFromPort(address localAddress, uint256 amount) external payable lock {
        IArbPort(localPortAddress).withdrawFromPort(msg.sender, msg.sender, localAddress, amount);
    }

    /*///////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to move gas to RootBridgeAgent for remote chain execution.
     *   @param _gasToBridgeOut amount of gas to be deposited.
     */
    function _depositGas(uint128 _gasToBridgeOut) internal override {
        address(wrappedNativeToken).safeTransfer(rootBridgeAgentAddress, _gasToBridgeOut);
    }

    /**
     * @notice Reverts the current transaction with a "no enough budget" message.
     * @dev This function is used to revert the current transaction with a "no enough budget" message.
     */
    function _forceRevert() internal pure override {
        revert GasErrorOrRepeatedTx();
    }

    /**
     * @notice Internal function performs call to AnycallProxy Contract for cross-chain messaging.
     *   @param _callData bytes of the call to be sent to the AnycallProxy.
     */
    function _performCall(bytes memory _callData) internal override {
        IRootBridgeAgent(rootBridgeAgentAddress).anyExecute(_callData);
    }

    /**
     * @notice Internal that clears gas allocated for usage with remote request
     */
    function _gasSwapIn(bytes memory gasData) internal override returns (uint256 gasAmount) {
        //Gas already provided by Root Bridge Agent
    }

    /**
     * @notice Internal function to pay for execution gas. Overwritten Gas is processed by Root Bridge Agent contract - `depositedGas` is used to pay for execution and `gasToBridgeOut`is cleared to recipient.
     */
    function _payExecutionGas(address _recipient, uint256) internal override {
        //Get gas remaining
        uint256 gasRemaining = wrappedNativeToken.balanceOf(address(this));

        if (gasRemaining > 0) {
            //Unwrap Gas
            wrappedNativeToken.withdraw(gasRemaining);

            //Transfer gas remaining to recipient
            SafeTransferLib.safeTransferETH(_recipient, gasRemaining);
        }

        delete(remoteCallDepositedGas);
    }

    /**
     * @notice Internal function to pay for fallback gas. Overwritten no cross-chain messaging fallback between Arbitrum Branch Bridge Agent and Root Bridge Agent.
     */
    function _payFallbackGas(uint32, uint256) internal override {
        //Cross-chain messaging + Fallback is managed by the Root Bridge Agent
    }

    /**
     * @notice Internal function to deposit gas to the AnycallProxy. Cross-chain messaging + Gas is managed by the Root Bridge Agent
     */
    function _replenishGas(uint256) internal override {}

    /// @notice Verifies the caller is the Anycall Executor. Internal function used in modifier to reduce contract bytesize.
    function _requiresExecutor() internal view override {
        if (msg.sender != rootBridgeAgentAddress) revert AnycallUnauthorizedCaller();
    }

    /// @notice Verifies enough gas is deposited to pay for an eventual fallback call. Reuse to reduce contract bytesize.
    function _requiresFallbackGas() internal view override {
        //Cross-chain messaging + Fallback is managed by the Root Bridge Agent
    }

    /// @notice Verifies enough gas is deposited to pay for an eventual fallback call.
    function _requiresFallbackGas(uint256) internal view override {
        //Cross-chain messaging + Fallback is managed by the Root Bridge Agent
    }

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error GasErrorOrRepeatedTx();
}
