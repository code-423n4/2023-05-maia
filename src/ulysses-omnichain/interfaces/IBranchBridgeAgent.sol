// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IApp} from "./IApp.sol";

struct UserFeeInfo {
    uint256 depositedGas;
    uint256 feesOwed;
}

enum DepositStatus {
    Success,
    Failed
}

struct Deposit {
    uint128 depositedGas;
    address owner;
    DepositStatus status;
    address[] hTokens;
    address[] tokens;
    uint256[] amounts;
    uint256[] deposits;
}

struct DepositInput {
    //Deposit Info
    address hToken; //Input Local hTokens Address.
    address token; //Input Native / underlying Token Address.
    uint256 amount; //Amount of Local hTokens deposited for interaction.
    uint256 deposit; //Amount of native tokens deposited for interaction.
    uint24 toChain; //Destination chain for interaction.
}

struct DepositMultipleInput {
    //Deposit Info
    address[] hTokens; //Input Local hTokens Address.
    address[] tokens; //Input Native / underlying Token Address.
    uint256[] amounts; //Amount of Local hTokens deposited for interaction.
    uint256[] deposits; //Amount of native tokens deposited for interaction.
    uint24 toChain; //Destination chain for interaction.
}

struct DepositParams {
    //Deposit Info
    uint32 depositNonce; //Deposit nonce.
    address hToken; //Input Local hTokens Address.
    address token; //Input Native / underlying Token Address.
    uint256 amount; //Amount of Local hTokens deposited for interaction.
    uint256 deposit; //Amount of native tokens deposited for interaction.
    uint24 toChain; //Destination chain for interaction.
    uint128 depositedGas; //BRanch chain gas token amount sent with request.
}

struct DepositMultipleParams {
    //Deposit Info
    uint8 numberOfAssets; //Number of assets to deposit.
    uint32 depositNonce; //Deposit nonce.
    address[] hTokens; //Input Local hTokens Address.
    address[] tokens; //Input Native / underlying Token Address.
    uint256[] amounts; //Amount of Local hTokens deposited for interaction.
    uint256[] deposits; //Amount of native tokens deposited for interaction.
    uint24 toChain; //Destination chain for interaction.
    uint128 depositedGas; //BRanch chain gas token amount sent with request.
}

struct SettlementParams {
    uint32 settlementNonce;
    address recipient;
    address hToken;
    address token;
    uint256 amount;
    uint256 deposit;
}

struct SettlementMultipleParams {
    uint8 numberOfAssets; //Number of assets to deposit.
    address recipient;
    uint32 settlementNonce;
    address[] hTokens;
    address[] tokens;
    uint256[] amounts;
    uint256[] deposits;
}

/**
 * @title  Branch Bridge Agent Contract
 * @author MaiaDAO
 * @notice Contract for deployment in Branch Chains of Omnichain System, responible for
 *         interfacing with Users and Routers acting as a middleman to access Anycall cross-chain
 *         messaging and  requesting / depositing  assets in the Branch Chain's Ports.
 * @dev    Bridge Agents allow for the encapsulation of business logic as well as the standardize
 *         cross-chain communication, allowing for the creation of custom Routers to perform
 *         actions as a response to remote user requests. This contract for deployment in the Branch
 *         Chains of the Ulysses Omnichain Liquidity System.
 *         This contract manages gas spenditure calling `_replenishingGas` after each remote initiated
 *         execution, as well as requests tokens clearances and tx execution to the `BranchBridgeAgentExecutor`.
 *         Remote execution is "sandboxed" in 3 different nestings:
 *         - 1: Anycall Messaging Layer will revert execution if by the end of the call the
 *              balance in the executionBudget AnycallConfig contract for the Branch Bridge Agent
 *              being called is inferior to the executionGasSpent, throwing the error `no enough budget`.
 *         - 2: The `BranchBridgeAgent` will trigger a revert all state changes if by the end of the remote initiated call
 *              Router interaction the userDepositedGas < executionGasSpent. This is done by calling the `_forceRevert()`
 *              internal function clearing all executionBudget from the AnycallConfig contract forcing the error `no enough budget`.
 *         - 3: The `BranchBridgeAgentExecutor` is in charge of requesting token deposits for each remote interaction as well
 *              as performing the Router calls, if any of the calls initiated by the Router lead to an invlaid state change
 *              both the token deposit clearances as well as the external interactions will be reverted. Yet executionGas
 *              will still be credited by the `BranchBridgeAgent`.
 *
 *         Func IDs for calling these functions through messaging layer:
 *
 *         BRANCH BRIDGE AGENT SETTLEMENT FLAGS
 *         --------------------------------------
 *         ID           | DESCRIPTION
 *         -------------+------------------------
 *         0x00         | Call to Branch without Settlement.
 *         0x01         | Call to Branch with Settlement.
 *         0x02         | Call to Branch with Settlement of Multiple Tokens.
 *
 *         Encoding Scheme for different Root Bridge Agent Deposit Flags:
 *
 *           - ht = hToken
 *           - t = Token
 *           - A = Amount
 *           - D = Destination
 *           - b = bytes
 *           - n = number of assets
 *           ________________________________________________________________________________________________________________________________
 *          |            Flag               |           Deposit Info           |             Token Info             |   DATA   |  Gas Info   |
 *          |           1 byte              |            4-25 bytes            |        (105 or 128) * n bytes      |   ---	   |  16 bytes   |
 *          |                               |                                  |            hT - t - A - D          |          |             |
 *          |_______________________________|__________________________________|____________________________________|__________|_____________|
 *          | callOut = 0x0                 |  20b(recipient) + 4b(nonce)      |            -------------           |   ---	   |     dep     |
 *          | callOutSingle = 0x1           |  20b(recipient) + 4b(nonce)      |         20b + 20b + 32b + 32b      |   ---	   |     16b     |
 *          | callOutMulti = 0x2            |  1b(n) + 20b(recipient) + 4b     |   	     32b + 32b + 32b + 32b      |   ---	   |     16b     |
 *          |_______________________________|__________________________________|____________________________________|__________|_____________|
 *
 *          Contract Remote Interaction Flow:
 *
 *          BranchBridgeAgent.anyExecute**() -> BridgeAgentExecutor.execute**() -> Router.anyExecute**() -> BridgeAgentExecutor (txExecuted) -> BranchBridgeAgent (replenishedGas)
 *
 *
 */
interface IBranchBridgeAgent is IApp {
    /**
     * @notice External function to return the Branch Bridge Agent Executor Address.
     */
    function bridgeAgentExecutorAddress() external view returns (address);

    /**
     * @dev External function that returns a given deposit entry.
     *     @param _depositNonce Identifier for user deposit.
     *
     */
    function getDepositEntry(uint32 _depositNonce) external view returns (Deposit memory);

    /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to perform a call to the Root Omnichain Router without token deposit.
     *   @param params enconded parameters to execute on the root chain router.
     *   @param remoteExecutionGas gas allocated for remote branch execution.
     *   @dev DEPOSIT ID: 1 (Call without deposit)
     *
     */
    function callOut(bytes calldata params, uint128 remoteExecutionGas) external payable;

    /**
     * @notice Function to perform a call to the Root Omnichain Router while depositing a single asset.
     *   @param params enconded parameters to execute on the root chain router.
     *   @param dParams additional token deposit parameters.
     *   @param remoteExecutionGas gas allocated for remote branch execution.
     *   @dev DEPOSIT ID: 2 (Call with single deposit)
     *
     */
    function callOutAndBridge(bytes calldata params, DepositInput memory dParams, uint128 remoteExecutionGas)
        external
        payable;

    /**
     * @notice Function to perform a call to the Root Omnichain Router while depositing two or more assets.
     *   @param params enconded parameters to execute on the root chain router.
     *   @param dParams additional token deposit parameters.
     *   @param remoteExecutionGas gas allocated for remote branch execution.
     *   @dev DEPOSIT ID: 3 (Call with multiple deposit)
     *
     */
    function callOutAndBridgeMultiple(
        bytes calldata params,
        DepositMultipleInput memory dParams,
        uint128 remoteExecutionGas
    ) external payable;

    /**
     * @notice Function to perform a call to the Root Omnichain Router without token deposit with msg.sender information.
     *   @param params enconded parameters to execute on the root chain router.
     *   @param remoteExecutionGas gas allocated for remote branch execution.
     *   @dev DEPOSIT ID: 4 (Call without deposit and verified sender)
     *
     */
    function callOutSigned(bytes calldata params, uint128 remoteExecutionGas) external payable;

    /**
     * @notice Function to perform a call to the Root Omnichain Router while depositing a single asset msg.sender.
     *   @param params enconded parameters to execute on the root chain router.
     *   @param dParams additional token deposit parameters.
     *   @param remoteExecutionGas gas allocated for remote branch execution.
     *   @dev DEPOSIT ID: 5 (Call with single deposit and verified sender)
     *
     */
    function callOutSignedAndBridge(bytes calldata params, DepositInput memory dParams, uint128 remoteExecutionGas)
        external
        payable;

    /**
     * @notice Function to perform a call to the Root Omnichain Router while depositing two or more assets with msg.sender.
     *   @param params enconded parameters to execute on the root chain router.
     *   @param dParams additional token deposit parameters.
     *   @param remoteExecutionGas gas allocated for remote branch execution.
     *   @dev DEPOSIT ID: 6 (Call with multiple deposit and verified sender)
     *
     */
    function callOutSignedAndBridgeMultiple(
        bytes calldata params,
        DepositMultipleInput memory dParams,
        uint128 remoteExecutionGas
    ) external payable;

    /**
     * @notice Function to perform a call to the Root Omnichain Environment retrying a failed deposit that hasn't been executed yet.
     *     @param _isSigned Flag to indicate if the deposit was signed.
     *     @param _depositNonce Identifier for user deposit.
     *     @param _params parameters to execute on the root chain router.
     *     @param _remoteExecutionGas gas allocated for remote branch execution.
     *     @param _toChain Destination chain for interaction.
     */
    function retryDeposit(
        bool _isSigned,
        uint32 _depositNonce,
        bytes calldata _params,
        uint128 _remoteExecutionGas,
        uint24 _toChain
    ) external payable;

    /**
     * @notice External function to retry a failed Settlement entry on the root chain.
     *     @param _settlementNonce Identifier for user settlement.
     *     @param _gasToBoostSettlement Amount of gas to boost settlement.
     *     @dev DEPOSIT ID: 7
     *
     */
    function retrySettlement(uint32 _settlementNonce, uint128 _gasToBoostSettlement) external payable;

    /**
     * @notice External function to request tokens back to branch chain after a failed omnichain environment interaction.
     *     @param _depositNonce Identifier for user deposit to retrieve.
     *     @dev DEPOSIT ID: 8
     *
     */
    function retrieveDeposit(uint32 _depositNonce) external payable;

    /**
     * @notice External function to retry a failed Deposit entry on this branch chain.
     *     @param _depositNonce Identifier for user deposit.
     *
     */
    function redeemDeposit(uint32 _depositNonce) external;

    /**
     * @notice Function to request balance clearance from a Port to a given user.
     *     @param _recipient token receiver.
     *     @param _hToken  local hToken addresse to clear balance for.
     *     @param _token  native / underlying token addresse to clear balance for.
     *     @param _amount amounts of hToken to clear balance for.
     *     @param _deposit amount of native / underlying tokens to clear balance for.
     *
     */
    function clearToken(address _recipient, address _hToken, address _token, uint256 _amount, uint256 _deposit)
        external;

    /**
     * @notice Function to request balance clearance from a Port to a given address.
     *     @param _sParams encode packed multiple settlement info.
     *
     */
    function clearTokens(bytes calldata _sParams, address _recipient)
        external
        returns (SettlementMultipleParams memory);

    /*///////////////////////////////////////////////////////////////
                        BRANCH ROUTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function performs call to AnycallProxy Contract for cross-chain messaging.
     *   @param params calldata for omnichain execution.
     *   @param depositor address of user depositing assets.
     *   @param gasToBridgeOut gas allocated for the cross-chain call.
     *   @param remoteExecutionGas gas allocated for omnichain execution.
     *   @dev DEPOSIT ID: 0 (System Call / Response)
     *   @dev 0x00 flag allows for identifying system emitted request/responses.
     *
     */
    function performSystemCallOut(
        address depositor,
        bytes memory params,
        uint128 gasToBridgeOut,
        uint128 remoteExecutionGas
    ) external payable;

    /**
     * @notice Internal function performs call to AnycallProxy Contract for cross-chain messaging.
     *   @param depositor address of user depositing assets.
     *   @param params calldata for omnichain execution.
     *   @param depositor address of user depositing assets.
     *   @param gasToBridgeOut gas allocated for the cross-chain call.
     *   @param remoteExecutionGas gas allocated for omnichain execution.
     *   @dev DEPOSIT ID: 1 (Call without Deposit)
     *
     */
    function performCallOut(address depositor, bytes memory params, uint128 gasToBridgeOut, uint128 remoteExecutionGas)
        external
        payable;

    /**
     * @notice Function to perform a call to the Root Omnichain Router while depositing a single asset.
     *   @param depositor address of user depositing assets.
     *   @param params enconded parameters to execute on the root chain router.
     *   @param dParams additional token deposit parameters.
     *   @param gasToBridgeOut gas allocated for the cross-chain call.
     *   @param remoteExecutionGas gas allocated for omnichain execution.
     *   @dev DEPOSIT ID: 2 (Call with single asset Deposit)
     *
     */
    function performCallOutAndBridge(
        address depositor,
        bytes calldata params,
        DepositInput memory dParams,
        uint128 gasToBridgeOut,
        uint128 remoteExecutionGas
    ) external payable;

    /**
     * @notice Function to perform a call to the Root Omnichain Router while depositing two or more assets.
     *   @param depositor address of user depositing assets.
     *   @param params enconded parameters to execute on the root chain router.
     *   @param dParams additional token deposit parameters.
     *   @param gasToBridgeOut gas allocated for the cross-chain call.
     *   @param remoteExecutionGas gas allocated for omnichain execution.
     *   @dev DEPOSIT ID: 3 (Call with multiple deposit)
     *
     */
    function performCallOutAndBridgeMultiple(
        address depositor,
        bytes calldata params,
        DepositMultipleInput memory dParams,
        uint128 gasToBridgeOut,
        uint128 remoteExecutionGas
    ) external payable;

    /*///////////////////////////////////////////////////////////////
                        ANYCALL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to force revert when a remote action does not have enough gas or is being retried after having been previously executed.
     */
    function forceRevert() external;

    /**
     * @notice Function to deposit gas for use by the Branch Bridge Agent.
     */
    function depositGasAnycallConfig() external payable;

    /*///////////////////////////////////////////////////////////////
                        EVENTS
    //////////////////////////////////////////////////////////////*/

    event LogCallin(bytes1 selector, bytes data, uint256 fromChainId);
    event LogCallout(bytes1 selector, bytes data, uint256, uint256 toChainId);
    event LogCalloutFail(bytes1 selector, bytes data, uint256 toChainId);

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error AnycallUnauthorizedCaller();
    error AlreadyExecutedTransaction();

    error InvalidInput();
    error InvalidChain();
    error InsufficientGas();

    error NotDepositOwner();
    error DepositRedeemUnavailable();

    error UnrecognizedCallerNotRouter();
    error UnrecognizedBridgeAgentExecutor();
}
