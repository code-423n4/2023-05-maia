// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IApp} from "./IApp.sol";

/*///////////////////////////////////////////////////////////////
                            STRUCTS
//////////////////////////////////////////////////////////////*/

struct SwapCallbackData {
    address tokenIn; //Token being sold
}

struct UserFeeInfo {
    uint128 depositedGas; //Gas deposited by user
    uint128 gasToBridgeOut; //Gas to be sent to bridge
}

struct GasPoolInfo {
    //zeroForOne when swapping gas from branch chain into root chain gas
    bool zeroForOneOnInflow;
    uint24 priceImpactPercentage; //Price impact percentage
    address poolAddress; //Uniswap V3 Pool Address
}

enum SettlementStatus {
    Success, //Settlement was successful
    Failed //Settlement failed
}

struct Settlement {
    uint24 toChain; //Destination chain for interaction.
    uint128 gasToBridgeOut; //Gas owed to user
    address owner; //Owner of the settlement
    address recipient; //Recipient of the settlement.
    SettlementStatus status; //Status of the settlement
    address[] hTokens; //Input Local hTokens Addresses.
    address[] tokens; //Input Native / underlying Token Addresses.
    uint256[] amounts; //Amount of Local hTokens deposited for interaction.
    uint256[] deposits; //Amount of native tokens deposited for interaction.
    bytes callData; //Call data for settlement
}

struct SettlementParams {
    uint32 settlementNonce; //Settlement nonce.
    address recipient; //Recipient of the settlement.
    address hToken; //Input Local hTokens Address.
    address token; //Input Native / underlying Token Address.
    uint256 amount; //Amount of Local hTokens deposited for interaction.
    uint256 deposit; //Amount of native tokens deposited for interaction.
}

struct SettlementMultipleParams {
    uint8 numberOfAssets; //Number of assets to deposit.
    uint32 settlementNonce; //Settlement nonce.
    address recipient; //Recipient of the settlement.
    address[] hTokens; //Input Local hTokens Addresses.
    address[] tokens; //Input Native / underlying Token Addresses.
    uint256[] amounts; //Amount of Local hTokens deposited for interaction.
    uint256[] deposits; //Amount of native tokens deposited for interaction.
}

struct DepositParams {
    //Deposit Info
    uint32 depositNonce; //Deposit nonce.
    address hToken; //Input Local hTokens Address.
    address token; //Input Native / underlying Token Address.
    uint256 amount; //Amount of Local hTokens deposited for interaction.
    uint256 deposit; //Amount of native tokens deposited for interaction.
    uint24 toChain; //Destination chain for interaction.
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
}

/**
 * @title  Root Bridge Agent Contract
 * @author MaiaDAO
 * @notice Contract responsible for interfacing with Users and Routers acting as a middleman to
 *         access Anycall cross-chain messaging and Port communication for asset management.
 * @dev    Bridge Agents allow for the encapsulation of business logic as well as the standardize
 *         cross-chain communication, allowing for the creation of custom Routers to perform
 *         actions as a response to remote user requests. This contract is for deployment in the Root
 *         Chain Omnichain Environment based on Arbitrum.
 *         This contract manages gas spenditure calling `_replenishingGas` after each remote initiated
 *         execution, as well as requests tokens clearances and tx execution from the `RootBridgeAgentExecutor`.
 *         Remote execution is "sandboxed" in 3 different nestings:
 *         - 1: Anycall Messaging Layer will revert execution if by the end of the call the
 *              balance in the executionBudget AnycallConfig contract to the Root Bridge Agent
 *              being called is inferior to the  executionGasSpent, throwing the error `no enough budget`.
 *         - 2: The `RootBridgeAgent` will trigger a revert all state changes if by the end of the remote initiated call
 *              Router interaction the userDepositedGas < executionGasSpent. This is done by calling the `_forceRevert()`
 *              internal function clearing all executionBudget from the AnycallConfig contract forcing the error `no enough budget`.
 *         - 3: The `RootBridgeAgentExecutor` is in charge of requesting token deposits for each remote interaction as well
 *              as performing the Router calls, if any of the calls initiated by the Router lead to an invlaid state change
 *              both the token deposit clearances as well as the external interactions will be reverted. Yet executionGas
 *              will still be credited by the `RootBridgeAgent`.
 *
 *          Func IDs for calling these  functions through messaging layer:
 *
 *          ROOT BRIDGE AGENT DEPOSIT FLAGS
 *          --------------------------------------
 *          ID           | DESCRIPTION
 *          -------------+------------------------
 *          0x00         | Branch Router Response.
 *          0x01         | Call to Root Router without Deposit.
 *          0x02         | Call to Root Router with Deposit.
 *          0x03         | Call to Root Router with Deposit of Multiple Tokens.
 *          0x04         | Call to Root Router without Deposit + singned message.
 *          0x05         | Call to Root Router with Deposit + singned message.
 *          0x06         | Call to Root Router with Deposit of Multiple Tokens + singned message.
 *          0x07         | Call to `retrySettlement()´. (retries sending a settlement + calldata for branch execution with new gas)
 *          0x08         | Call to `clearDeposit()´. (clears a deposit that has not been executed yet triggering `anyFallback`)
 *
 *
 *          Encoding Scheme for different Root Bridge Agent Deposit Flags:
 *
 *           - ht = hToken
 *           - t = Token
 *           - A = Amount
 *           - D = Destination
 *           - C = ChainId
 *           - b = bytes
 *           - n = number of assets
 *           ___________________________________________________________________________________________________________________________
 *          |            Flag               |        Deposit Info        |             Token Info             |   DATA   |  Gas Info   |
 *          |           1 byte              |         4-25 bytes         |     3 + (105 or 128) * n bytes     |   ---	 |  32 bytes   |
 *          |                               |                            |          hT - t - A - D - C        |          |             |
 *          |_______________________________|____________________________|____________________________________|__________|_____________|
 *          | callOutSystem = 0x0   	    |                 4b(nonce)  |            -------------           |   ---	 |  dep + bOut |
 *          | callOut = 0x1                 |                 4b(nonce)  |            -------------           |   ---	 |  dep + bOut |
 *          | callOutSingle = 0x2           |                 4b(nonce)  |      20b + 20b + 32b + 32b + 3b    |   ---	 |  16b + 16b  |
 *          | callOutMulti = 0x3            |         1b(n) + 4b(nonce)  |   	32b + 32b + 32b + 32b + 3b    |   ---	 |  16b + 16b  |
 *          | callOutSigned = 0x4           |    20b(recip) + 4b(nonce)  |   	      -------------           |   ---    |  16b + 16b  |
 *          | callOutSignedSingle = 0x5     |           20b + 4b(nonce)  |      20b + 20b + 32b + 32b + 3b 	  |   ---	 |  16b + 16b  |
 *          | callOutSignedMultiple = 0x6   |   20b + 1b(n) + 4b(nonce)  |      32b + 32b + 32b + 32b + 3b 	  |   ---	 |  16b + 16b  |
 *          |_______________________________|____________________________|____________________________________|__________|_____________|
 *
 *          Contract Interaction Flows:
 *
 *          - 1) Remote to Remote:
 *                  RootBridgeAgent.anyExecute**() -> BridgeAgentExecutor.execute**() -> Router.anyExecute**() -> BridgeAgentExecutor (txExecuted) -> RootBridgeAgent (replenishedGas)
 *
 *          - 2) Remote to Arbitrum:
 *                  RootBridgeAgent.anyExecute**() -> BridgeAgentExecutor.execute**() -> Router.anyExecute**() -> BridgeAgentExecutor (txExecuted) -> RootBridgeAgent (replenishedGas)
 *
 *          - 3) Arbitrum to Arbitrum:
 *                  RootBridgeAgent.anyExecute**() -> BridgeAgentExecutor.execute**() -> Router.anyExecute**() -> BridgeAgentExecutor (txExecuted)
 *
 */
interface IRootBridgeAgent is IApp {
    /*///////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice External function to get the intial gas available for remote request execution.
     *   @return uint256 Initial gas available for remote request execution.
     */
    function initialGas() external view returns (uint256);

    /**
     * @notice External get gas fee details for current remote request being executed.
     *   @return uint256 Gas fee for remote request execution.
     *   @return uint256 Gas fee for remote request execution.
     */
    function userFeeInfo() external view returns (uint128, uint128);

    /**
     * @notice External function to get the Bridge Agent Executor Address.
     * @return address Bridge Agent Executor Address.
     */
    function bridgeAgentExecutorAddress() external view returns (address);

    /**
     * @notice External function to get the Root Bridge Agent's Factory Address.
     *   @return address Root Bridge Agent's Factory Address.
     */
    function factoryAddress() external view returns (address);

    /**
     * @notice External function to get the attached Branch Bridge Agent for a given chain.
     *   @param _chainId Chain ID of the Branch Bridge Agent.
     *   @return address Branch Bridge Agent Address.
     */
    function getBranchBridgeAgent(uint256 _chainId) external view returns (address);

    /**
     * @notice External function to verify a given chain has been allowed by the Root Bridge Agent's Manager for new Branch Bridge Agent creation.
     *   @param _chainId Chain ID of the Branch Bridge Agent.
     *   @return bool True if the chain has been allowed for new Branch Bridge Agent creation.
     */
    function isBranchBridgeAgentAllowed(uint256 _chainId) external view returns (bool);

    /*///////////////////////////////////////////////////////////////
                            REMOTE CALL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice External function performs call to AnycallProxy Contract for cross-chain messaging.
     *   @param _recipient address to receive any outstanding gas on the destination chain.
     *   @param _calldata Calldata for function call.
     *   @param _toChain Chain to bridge to.
     *   @dev Internal function performs call to AnycallProxy Contract for cross-chain messaging.
     */
    function callOut(address _recipient, bytes memory _calldata, uint24 _toChain) external payable;

    /**
     * @notice External function to move assets from root chain to branch omnichain envirsonment.
     *   @param _owner address allowed for redeeming assets after a failed settlement fallback. This address' Virtual Account is also allowed.
     *   @param _recipient recipient of bridged tokens and any outstanding gas on the destination chain.
     *   @param _data parameters for function call on branch chain.
     *   @param _globalAddress global token to be moved.
     *   @param _amount amount of ´token´.
     *   @param _deposit amount of native / underlying token.
     *   @param _toChain chain to bridge to.
     *
     */
    function callOutAndBridge(
        address _owner,
        address _recipient,
        bytes memory _data,
        address _globalAddress,
        uint256 _amount,
        uint256 _deposit,
        uint24 _toChain
    ) external payable;

    /**
     * @notice External function to move assets from branch chain to root omnichain environment.
     *   @param _owner address allowed for redeeming assets after a failed settlement fallback. This address' Virtual Account is also allowed.
     *   @param _recipient recipient of bridged tokens.
     *   @param _data parameters for function call on branch chain.
     *   @param _globalAddresses global tokens to be moved.
     *   @param _amounts amounts of token.
     *   @param _deposits amounts of underlying / token.
     *   @param _toChain chain to bridge to.
     *
     *
     */
    function callOutAndBridgeMultiple(
        address _owner,
        address _recipient,
        bytes memory _data,
        address[] memory _globalAddresses,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        uint24 _toChain
    ) external payable;

    /*///////////////////////////////////////////////////////////////
                        TOKEN MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to move assets from branch chain to root omnichain environment. Called in response to Bridge Agent Executor.
     *   @param _dParams Cross-Chain Deposit of Multiple Tokens Params.
     *   @param _fromChain chain to bridge from.
     *
     */
    function bridgeIn(address _recipient, DepositParams memory _dParams, uint24 _fromChain) external;

    /**
     * @notice Function to move assets from branch chain to root omnichain environment. Called in response to Bridge Agent Executor.
     *   @param _dParams Cross-Chain Deposit of Multiple Tokens Params.
     *   @param _fromChain chain to bridge from.
     *   @dev Since the input data is encodePacked we need to parse it:
     *     1. First byte is the number of assets to be bridged in. Equals length of all arrays.
     *     2. Next 4 bytes are the nonce of the deposit.
     *     3. Last 32 bytes after the token related information are the chain to bridge to.
     *     4. Token related information starts at index PARAMS_TKN_START is encoded as follows:
     *         1. N * 32 bytes for the hToken address.
     *         2. N * 32 bytes for the underlying token address.
     *         3. N * 32 bytes for the amount of hTokens to be bridged in.
     *         4. N * 32 bytes for the amount of underlying tokens to be bridged in.
     *     5. Each of the 4 token related arrays are of length N and start at the following indexes:
     *         1. PARAMS_TKN_START [hToken address has no offset from token information start].
     *         2. PARAMS_TKN_START + (PARAMS_ADDRESS_SIZE * N)
     *         3. PARAMS_TKN_START + (PARAMS_AMT_OFFSET * N)
     *         4. PARAMS_TKN_START + (PARAMS_DEPOSIT_OFFSET * N)
     *
     */
    function bridgeInMultiple(address _recipient, DepositMultipleParams memory _dParams, uint24 _fromChain) external;

    /*///////////////////////////////////////////////////////////////
                        SETTLEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function that returns the current settlement nonce.
     *   @return nonce bridge agent's current settlement nonce
     *
     */
    function settlementNonce() external view returns (uint32 nonce);

    /**
     * @notice Function that allows redemption of failed Settlement's global tokens.
     *   @param _depositNonce Identifier for token deposit.
     *
     */
    function redeemSettlement(uint32 _depositNonce) external;

    /**
     * @notice Function to retry a user's Settlement balance.
     *   @param _settlementNonce Identifier for token settlement.
     *   @param _remoteExecutionGas Identifier for token settlement.
     *
     */
    function retrySettlement(uint32 _settlementNonce, uint128 _remoteExecutionGas) external payable;

    /**
     * @notice External function that returns a given settlement entry.
     *   @param _settlementNonce Identifier for token settlement.
     *
     */
    function getSettlementEntry(uint32 _settlementNonce) external view returns (Settlement memory);

    /**
     * @notice Updates the address of the branch bridge agent
     *   @param _newBranchBridgeAgent address of the new branch bridge agent
     *   @param _branchChainId chainId of the branch chain
     */
    function syncBranchBridgeAgent(address _newBranchBridgeAgent, uint24 _branchChainId) external;

    /*///////////////////////////////////////////////////////////////
                            GAS SWAP FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks if a pool is eligible to call uniswapV3SwapCallback
     *   @param amount0 amount of token0 to swap
     *   @param amount1 amount of token1 to swap
     *   @param _data abi encoded data
     */
    function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes calldata _data) external;

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

    /**
     * @notice Function to collect excess gas fees.
     *   @dev only callable by the DAO.
     */
    function sweep() external;

    /*///////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new branch bridge agent to a given branch chainId
     *   @param _branchChainId chainId of the branch chain
     */
    function approveBranchBridgeAgent(uint256 _branchChainId) external;

    /*///////////////////////////////////////////////////////////////
                             EVENTS
    //////////////////////////////////////////////////////////////*/

    event LogCallin(bytes1 selector, bytes data, uint24 fromChainId);
    event LogCallout(bytes1 selector, bytes data, uint256, uint24 toChainId);
    event LogCalloutFail(bytes1 selector, bytes data, uint24 toChainId);

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error GasErrorOrRepeatedTx();

    error NotDao();
    error AnycallUnauthorizedCaller();

    error AlreadyAddedBridgeAgent();
    error UnrecognizedExecutor();
    error UnrecognizedPort();
    error UnrecognizedBridgeAgent();
    error UnrecognizedBridgeAgentManager();
    error UnrecognizedCallerNotRouter();

    error UnrecognizedUnderlyingAddress();
    error UnrecognizedLocalAddress();
    error UnrecognizedGlobalAddress();
    error UnrecognizedAddressInDestination();

    error SettlementRedeemUnavailable();
    error NotSettlementOwner();

    error InsufficientBalanceForSettlement();
    error InsufficientGasForFees();
    error InvalidInputParams();
    error InvalidGasPool();

    error CallerIsNotPool();
    error AmountsAreZero();
}
