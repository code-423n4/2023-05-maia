// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {WETH9} from "./interfaces/IWETH9.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {AnycallFlags} from "./lib/AnycallFlags.sol";

import {IAnycallProxy} from "./interfaces/IAnycallProxy.sol";
import {IAnycallConfig} from "./interfaces/IAnycallConfig.sol";
import {IAnycallExecutor} from "./interfaces/IAnycallExecutor.sol";

import {IApp, IRootBridgeAgent} from "./interfaces/IRootBridgeAgent.sol";
import {IBranchBridgeAgent} from "./interfaces/IBranchBridgeAgent.sol";
import {IERC20hTokenRoot} from "./interfaces/IERC20hTokenRoot.sol";
import {IRootPort as IPort} from "./interfaces/IRootPort.sol";
import {IRootRouter as IRouter} from "./interfaces/IRootRouter.sol";

import {VirtualAccount} from "./VirtualAccount.sol";
import {
    IRootBridgeAgent,
    DepositParams,
    DepositMultipleParams,
    Settlement,
    SettlementStatus,
    SettlementParams,
    SettlementMultipleParams,
    UserFeeInfo,
    SwapCallbackData
} from "./interfaces/IRootBridgeAgent.sol";

import {DeployRootBridgeAgentExecutor, RootBridgeAgentExecutor} from "./RootBridgeAgentExecutor.sol";

/// @title Library for Cross Chain Deposit Parameters Validation.
library CheckParamsLib {
    /**
     * @notice Function to check cross-chain deposit parameters and verify deposits made on branch chain are valid.
     * @param _localPortAddress Address of local Port.
     * @param _dParams Cross Chain swap parameters.
     * @param _fromChain Chain ID of the chain where the deposit was made.
     * @dev Local hToken must be recognized and address must match underlying if exists otherwise only local hToken is checked.
     *
     */
    function checkParams(address _localPortAddress, DepositParams memory _dParams, uint24 _fromChain)
        internal
        view
        returns (bool)
    {
        if (
            (_dParams.amount < _dParams.deposit) //Deposit can't be greater than amount.
                || (_dParams.amount > 0 && !IPort(_localPortAddress).isLocalToken(_dParams.hToken, _fromChain)) //Check local exists.
                || (_dParams.deposit > 0 && !IPort(_localPortAddress).isUnderlyingToken(_dParams.token, _fromChain)) //Check underlying exists.
        ) {
            return false;
        }
        return true;
    }
}

/// @title Library for Root Bridge Agent Deployment.
library DeployRootBridgeAgent {
    function deploy(
        WETH9 _wrappedNativeToken,
        uint24 _localChainId,
        address _daoAddress,
        address _localAnyCallAddress,
        address _localAnyCallExecutorAddress,
        address _localPortAddress,
        address _localRouterAddress
    ) external returns (RootBridgeAgent) {
        return new RootBridgeAgent(
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

/// @title  Root Bridge Agent Contract
contract RootBridgeAgent is IRootBridgeAgent {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;

    /*///////////////////////////////////////////////////////////////
                            ENCODING CONSTS
    //////////////////////////////////////////////////////////////*/

    /// AnyExec Consts

    uint8 internal constant PARAMS_START = 1;

    uint8 internal constant PARAMS_START_SIGNED = 21;

    uint8 internal constant PARAMS_ADDRESS_SIZE = 20;

    uint8 internal constant PARAMS_GAS_IN = 32;

    uint8 internal constant PARAMS_GAS_OUT = 16;

    /// BridgeIn Consts

    uint8 internal constant PARAMS_TKN_START = 5;

    uint8 internal constant PARAMS_AMT_OFFSET = 64;

    uint8 internal constant PARAMS_DEPOSIT_OFFSET = 96;

    /*///////////////////////////////////////////////////////////////
                        ROOT BRIDGE AGENT STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Local Chain Id
    uint24 public immutable localChainId;

    /// @notice Local Wrapped Native Token
    WETH9 public immutable wrappedNativeToken;

    /// @notice Bridge Agent Factory Address.
    address public immutable factoryAddress;

    /// @notice Address of DAO.
    address public immutable daoAddress;

    /// @notice Local Core Root Router Address
    address public immutable localRouterAddress;

    /// @notice Address for Local Port Address where funds deposited from this chain are stored.
    address public immutable localPortAddress;

    /// @notice Local Anycall Address
    address public immutable localAnyCallAddress;

    /// @notice Local Anyexec Address
    address public immutable localAnyCallExecutorAddress;

    /// @notice Address of Root Bridge Agent Executor.
    address public immutable bridgeAgentExecutorAddress;

    /*///////////////////////////////////////////////////////////////
                    BRANCH BRIDGE AGENTS STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Chain -> Branch Bridge Agent Address. For N chains, each Root Bridge Agent Address has M =< N Branch Bridge Agent Address.
    mapping(uint256 => address) public getBranchBridgeAgent;

    /// @notice If true, bridge agent manager has allowed for a new given branch bridge agent to be synced/added.
    mapping(uint256 => bool) public isBranchBridgeAgentAllowed;

    /*///////////////////////////////////////////////////////////////
                        SETTLEMENTS STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit nonce used for identifying transaction.
    uint32 public settlementNonce;

    /// @notice Mapping from Settlement nonce to Deposit Struct.
    mapping(uint32 => Settlement) public getSettlement;

    /*///////////////////////////////////////////////////////////////
                            EXECUTOR STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice If true, bridge agent has already served a request with this nonce from  a given chain. Chain -> Nonce -> Bool
    mapping(uint256 => mapping(uint32 => bool)) public executionHistory;

    /*///////////////////////////////////////////////////////////////
                        GAS MANAGEMENT STATE
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant MIN_FALLBACK_RESERVE = 155_000; // 100_000 for anycall + 55_000 for fallback
    uint256 internal constant MIN_EXECUTION_OVERHEAD = 155_000; // 100_000 for anycall + 30_000 Pre 1st Gas Checkpoint Execution + 25_000 Post last Gas Checkpoint Execution

    uint256 public initialGas;
    UserFeeInfo public userFeeInfo;

    /*///////////////////////////////////////////////////////////////
                        DAO STATE
    //////////////////////////////////////////////////////////////*/

    uint256 public accumulatedFees;

    /**
     * @notice Constructor for Bridge Agent.
     *     @param _wrappedNativeToken Local Wrapped Native Token.
     *     @param _daoAddress Address of DAO.
     *     @param _localChainId Local Chain Id.
     *     @param _localAnyCallAddress Local Anycall Address.
     *     @param _localPortAddress Local Port Address.
     *     @param _localRouterAddress Local Port Address.
     */
    constructor(
        WETH9 _wrappedNativeToken,
        uint24 _localChainId,
        address _daoAddress,
        address _localAnyCallAddress,
        address _localAnyCallExecutorAddress,
        address _localPortAddress,
        address _localRouterAddress
    ) {
        require(address(_wrappedNativeToken) != address(0), "Wrapped native token cannot be zero address");
        require(_daoAddress != address(0), "DAO cannot be zero address");
        require(_localAnyCallAddress != address(0), "Anycall Address cannot be zero address");
        require(_localAnyCallExecutorAddress != address(0), "Anycall Executor Address cannot be zero address");
        require(_localPortAddress != address(0), "Port Address cannot be zero address");
        require(_localRouterAddress != address(0), "Router Address cannot be zero address");

        wrappedNativeToken = _wrappedNativeToken;
        factoryAddress = msg.sender;
        daoAddress = _daoAddress;
        localChainId = _localChainId;
        localAnyCallAddress = _localAnyCallAddress;
        localPortAddress = _localPortAddress;
        localRouterAddress = _localRouterAddress;
        bridgeAgentExecutorAddress = DeployRootBridgeAgentExecutor.deploy(address(this));
        localAnyCallExecutorAddress = _localAnyCallExecutorAddress;
        settlementNonce = 1;
        accumulatedFees = 1; //Avoid paying 20k gas in first `payExecutionGas` making MIN_EXECUTION_OVERHEAD constant.
    }

    /*///////////////////////////////////////////////////////////////
                        VIEW EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRootBridgeAgent
    function getSettlementEntry(uint32 _settlementNonce) external view returns (Settlement memory) {
        return getSettlement[_settlementNonce];
    }

    /*///////////////////////////////////////////////////////////////
                        USER EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRootBridgeAgent
    function retrySettlement(uint32 _settlementNonce, uint128 _remoteExecutionGas) external payable {
        //Update User Gas available.
        if (initialGas == 0) {
            userFeeInfo.depositedGas = uint128(msg.value);
            userFeeInfo.gasToBridgeOut = _remoteExecutionGas;
        }
        //Clear Settlement with updated gas.
        _retrySettlement(_settlementNonce);
    }

    /// @inheritdoc IRootBridgeAgent
    function redeemSettlement(uint32 _depositNonce) external lock {
        //Get deposit owner.
        address depositOwner = getSettlement[_depositNonce].owner;

        //Update Deposit
        if (getSettlement[_depositNonce].status != SettlementStatus.Failed || depositOwner == address(0)) {
            revert SettlementRedeemUnavailable();
        } else if (
            msg.sender != depositOwner && msg.sender != address(IPort(localPortAddress).getUserAccount(depositOwner))
        ) {
            revert NotSettlementOwner();
        }
        _redeemSettlement(_depositNonce);
    }

    /*///////////////////////////////////////////////////////////////
                    ROOT ROUTER EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRootBridgeAgent
    function callOut(address _recipient, bytes memory _data, uint24 _toChain) external payable lock requiresRouter {
        //Encode Data for call.
        bytes memory data =
            abi.encodePacked(bytes1(0x00), _recipient, settlementNonce++, _data, _manageGasOut(_toChain));

        //Perform Call to clear hToken balance on destination branch chain.
        _performCall(data, _toChain);
    }

    /// @inheritdoc IRootBridgeAgent
    function callOutAndBridge(
        address _owner,
        address _recipient,
        bytes memory _data,
        address _globalAddress,
        uint256 _amount,
        uint256 _deposit,
        uint24 _toChain
    ) external payable lock requiresRouter {
        //Get destination Local Address from Global Address.
        address localAddress = IPort(localPortAddress).getLocalTokenFromGlobal(_globalAddress, _toChain);

        //Get destination Underlying Address from Local Address.
        address underlyingAddress = IPort(localPortAddress).getUnderlyingTokenFromLocal(localAddress, _toChain);

        //Check if valid assets
        if (localAddress == address(0) || (underlyingAddress == address(0) && _deposit > 0)) {
            revert InvalidInputParams();
        }

        //Prepare data for call
        bytes memory data = abi.encodePacked(
            bytes1(0x01),
            _recipient,
            settlementNonce,
            localAddress,
            underlyingAddress,
            _amount,
            _deposit,
            _data,
            _manageGasOut(_toChain)
        );

        //Update State to reflect bridgeOut
        _updateStateOnBridgeOut(
            msg.sender, _globalAddress, localAddress, underlyingAddress, _amount, _deposit, _toChain
        );

        //Create Settlement
        _createSettlement(_owner, _recipient, localAddress, underlyingAddress, _amount, _deposit, data, _toChain);

        //Perform Call to clear hToken balance on destination branch chain and perform call.
        _performCall(data, _toChain);
    }

    /// @inheritdoc IRootBridgeAgent
    function callOutAndBridgeMultiple(
        address _owner,
        address _recipient,
        bytes memory _data,
        address[] memory _globalAddresses,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        uint24 _toChain
    ) external payable lock requiresRouter {
        address[] memory hTokens = new address[](_globalAddresses.length);
        address[] memory tokens = new address[](_globalAddresses.length);
        for (uint256 i = 0; i < _globalAddresses.length;) {
            //Populate Addresses for Settlement
            hTokens[i] = IPort(localPortAddress).getLocalTokenFromGlobal(_globalAddresses[i], _toChain);
            tokens[i] = IPort(localPortAddress).getUnderlyingTokenFromLocal(hTokens[i], _toChain);

            if (hTokens[i] == address(0) || (tokens[i] == address(0) && _deposits[i] > 0)) revert InvalidInputParams();

            _updateStateOnBridgeOut(
                msg.sender, _globalAddresses[i], hTokens[i], tokens[i], _amounts[i], _deposits[i], _toChain
            );

            unchecked {
                ++i;
            }
        }

        //Prepare data for call with settlement of multiple assets
        bytes memory data = abi.encodePacked(
            bytes1(0x02),
            _recipient,
            uint8(hTokens.length),
            settlementNonce,
            hTokens,
            tokens,
            _amounts,
            _deposits,
            _data,
            _manageGasOut(_toChain)
        );

        //Create Settlement Balance
        _createMultipleSettlement(_owner, _recipient, hTokens, tokens, _amounts, _deposits, data, _toChain);

        //Perform Call to destination Branch Chain.
        _performCall(data, _toChain);
    }

    /*///////////////////////////////////////////////////////////////
                    TOKEN MANAGEMENT EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRootBridgeAgent
    function bridgeIn(address _recipient, DepositParams memory _dParams, uint24 _fromChain)
        public
        requiresAgentExecutor
    {
        //Check Deposit info from Cross Chain Parameters.
        if (!CheckParamsLib.checkParams(localPortAddress, _dParams, _fromChain)) {
            revert InvalidInputParams();
        }

        //Get global address
        address globalAddress = IPort(localPortAddress).getGlobalTokenFromLocal(_dParams.hToken, _fromChain);

        //Check if valid asset
        if (globalAddress == address(0)) revert InvalidInputParams();

        //Move hTokens from Branch to Root + Mint Sufficient hTokens to match new port deposit
        IPort(localPortAddress).bridgeToRoot(_recipient, globalAddress, _dParams.amount, _dParams.deposit, _fromChain);
    }

    /// @inheritdoc IRootBridgeAgent
    function bridgeInMultiple(address _recipient, DepositMultipleParams memory _dParams, uint24 _fromChain)
        external
        requiresAgentExecutor
    {
        for (uint256 i = 0; i < _dParams.hTokens.length;) {
            bridgeIn(
                _recipient,
                DepositParams({
                    hToken: _dParams.hTokens[i],
                    token: _dParams.tokens[i],
                    amount: _dParams.amounts[i],
                    deposit: _dParams.deposits[i],
                    toChain: _dParams.toChain,
                    depositNonce: 0
                }),
                _fromChain
            );

            unchecked {
                ++i;
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                    TOKEN MANAGEMENT INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the token balance state by moving assets from root omnichain environment to branch chain, when a user wants to bridge out tokens from the root bridge agent chain.
     *     @param _sender address of the sender.
     *     @param _globalAddress address of the global token.
     *     @param _localAddress address of the local token.
     *     @param _underlyingAddress address of the underlying token.
     *     @param _amount amount of hTokens to be bridged out.
     *     @param _deposit amount of underlying tokens to be bridged out.
     *     @param _toChain chain to bridge to.
     */
    function _updateStateOnBridgeOut(
        address _sender,
        address _globalAddress,
        address _localAddress,
        address _underlyingAddress,
        uint256 _amount,
        uint256 _deposit,
        uint24 _toChain
    ) internal {
        if (_amount - _deposit > 0) {
            //Move output hTokens from Root to Branch
            if (_localAddress == address(0)) revert UnrecognizedLocalAddress();
            _globalAddress.safeTransferFrom(_sender, localPortAddress, _amount - _deposit);
        }

        if (_deposit > 0) {
            //Verify there is enough balance to clear native tokens if needed
            if (_underlyingAddress == address(0)) revert UnrecognizedUnderlyingAddress();
            if (IERC20hTokenRoot(_globalAddress).getTokenBalance(_toChain) < _deposit) {
                revert InsufficientBalanceForSettlement();
            }
            IPort(localPortAddress).burn(_sender, _globalAddress, _deposit, _toChain);
        }
    }

    /*///////////////////////////////////////////////////////////////
                SETTLEMENT INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to store a Settlement instance. Settlement should be reopened if fallback occurs.
     *    @param _owner settlement owner address.
     *    @param _recipient destination chain reciever address.
     *    @param _hToken deposited global token address.
     *    @param _token deposited global token address.
     *    @param _amount amounts of total hTokens + Tokens output.
     *    @param _deposit amount of underlying / native token to output.
     *    @param _callData calldata to execute on destination Router.
     *    @param _toChain Destination chain identificator.
     *
     */
    function _createSettlement(
        address _owner,
        address _recipient,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        bytes memory _callData,
        uint24 _toChain
    ) internal {
        //Cast to Dynamic
        address[] memory hTokens = new address[](1);
        hTokens[0] = _hToken;
        address[] memory tokens = new address[](1);
        tokens[0] = _token;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;
        uint256[] memory deposits = new uint256[](1);
        deposits[0] = _deposit;

        //Call createSettlement
        _createMultipleSettlement(_owner, _recipient, hTokens, tokens, amounts, deposits, _callData, _toChain);
    }

    /**
     * @notice Function to create a settlemment. Settlement should be reopened if fallback occurs.
     *    @param _owner settlement owner address.
     *    @param _recipient destination chain reciever address.
     *    @param _hTokens deposited global token addresses.
     *    @param _tokens deposited global token addresses.
     *    @param _amounts amounts of total hTokens + Tokens output.
     *    @param _deposits amount of underlying / native tokens to output.
     *    @param _callData calldata to execute on destination Router.
     *    @param _toChain Destination chain identificator.
     *
     *
     */
    function _createMultipleSettlement(
        address _owner,
        address _recipient,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        bytes memory _callData,
        uint24 _toChain
    ) internal {
        // Update State
        getSettlement[_getAndIncrementSettlementNonce()] = Settlement({
            owner: _owner,
            recipient: _recipient,
            hTokens: _hTokens,
            tokens: _tokens,
            amounts: _amounts,
            deposits: _deposits,
            callData: _callData,
            toChain: _toChain,
            status: SettlementStatus.Success,
            gasToBridgeOut: userFeeInfo.gasToBridgeOut
        });
    }

    /**
     * @notice Function to retry a user's Settlement balance with a new amount of gas to bridge out of Root Bridge Agent's Omnichain Environment.
     *    @param _settlementNonce Identifier for token settlement.
     *
     */
    function _retrySettlement(uint32 _settlementNonce) internal returns (bool) {
        //Get Settlement
        Settlement memory settlement = getSettlement[_settlementNonce];

        //Check if Settlement hasn't been redeemed.
        if (settlement.owner == address(0)) return false;

        //abi encodePacked
        bytes memory newGas = abi.encodePacked(_manageGasOut(settlement.toChain));

        //overwrite last 16bytes of callData
        for (uint256 i = 0; i < newGas.length;) {
            settlement.callData[settlement.callData.length - 16 + i] = newGas[i];
            unchecked {
                ++i;
            }
        }

        Settlement storage settlementReference = getSettlement[_settlementNonce];

        //Update Gas To Bridge Out
        settlementReference.gasToBridgeOut = userFeeInfo.gasToBridgeOut;

        //Set Settlement Calldata to send to Branch Chain
        settlementReference.callData = settlement.callData;

        //Update Settlement Staus
        settlementReference.status = SettlementStatus.Success;

        //Retry call with additional gas
        _performCall(settlement.callData, settlement.toChain);

        //Retry Success
        return true;
    }

    /**
     * @notice Function to retry a user's Settlement balance.
     *     @param _settlementNonce Identifier for token settlement.
     *
     */
    function _redeemSettlement(uint32 _settlementNonce) internal {
        // Get storage reference
        Settlement storage settlement = getSettlement[_settlementNonce];

        //Clear Global hTokens To Recipient on Root Chain cancelling Settlement to Branch
        for (uint256 i = 0; i < settlement.hTokens.length;) {
            //Check if asset
            if (settlement.hTokens[i] != address(0)) {
                //Move hTokens from Branch to Root + Mint Sufficient hTokens to match new port deposit
                IPort(localPortAddress).bridgeToRoot(
                    msg.sender,
                    IPort(localPortAddress).getGlobalTokenFromLocal(settlement.hTokens[i], settlement.toChain),
                    settlement.amounts[i],
                    settlement.deposits[i],
                    settlement.toChain
                );
            }

            unchecked {
                ++i;
            }
        }

        // Delete Settlement
        delete getSettlement[_settlementNonce];
    }

    /**
     * @notice Function to reopen a user's Settlement balance as pending and thus retryable by users. Called upon anyFallback of triggered by Branch Bridge Agent.
     *     @param _settlementNonce Identifier for token settlement.
     *
     */
    function _reopenSettlemment(uint32 _settlementNonce) internal {
        //Update Deposit
        getSettlement[_settlementNonce].status = SettlementStatus.Failed;
    }

    /**
     * @notice Function that returns Deposit nonce and increments nonce counter.
     *
     */
    function _getAndIncrementSettlementNonce() internal returns (uint32) {
        return settlementNonce++;
    }

    /*///////////////////////////////////////////////////////////////
                    GAS SWAP INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    uint24 private constant GLOBAL_DIVISIONER = 1e6; // for basis point (0.0001%)

    //Local mapping of valid gas pools
    mapping(address => bool) private approvedGasPool;

    /// @inheritdoc IRootBridgeAgent
    function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes calldata _data) external {
        if (!approvedGasPool[msg.sender]) revert CallerIsNotPool();
        if (amount0 == 0 && amount1 == 0) revert AmountsAreZero();
        SwapCallbackData memory data = abi.decode(_data, (SwapCallbackData));

        address(data.tokenIn).safeTransfer(msg.sender, uint256(amount0 > 0 ? amount0 : amount1));
    }

    /**
     * @notice Swaps gas tokens from the given branch chain to the root chain
     * @param _amount amount of gas token to swap
     * @param _fromChain chain to swap from
     */
    function _gasSwapIn(uint256 _amount, uint24 _fromChain) internal returns (uint256) {
        //Get fromChain's Gas Pool Info
        (bool zeroForOneOnInflow, uint24 priceImpactPercentage, address gasTokenGlobalAddress, address poolAddress) =
            IPort(localPortAddress).getGasPoolInfo(_fromChain);

        //Check if valid addresses
        if (gasTokenGlobalAddress == address(0) || poolAddress == address(0)) revert InvalidGasPool();

        //Move Gas hTokens from Branch to Root / Mint Sufficient hTokens to match new port deposit
        IPort(localPortAddress).bridgeToRoot(address(this), gasTokenGlobalAddress, _amount, _amount, _fromChain);

        //Save Gas Pool for future use
        if (!approvedGasPool[poolAddress]) approvedGasPool[poolAddress] = true;

        //Get sqrtPriceX96
        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(poolAddress).slot0();

        // Calculate Price limit depending on pre-set price impact
        uint160 exactSqrtPriceImpact = (sqrtPriceX96 * (priceImpactPercentage / 2)) / GLOBAL_DIVISIONER;

        //Get limit
        uint160 sqrtPriceLimitX96 =
            zeroForOneOnInflow ? sqrtPriceX96 - exactSqrtPriceImpact : sqrtPriceX96 + exactSqrtPriceImpact;

        //Swap imbalanced token as long as we haven't used the entire amountSpecified and haven't reached the price limit
        try IUniswapV3Pool(poolAddress).swap(
            address(this),
            zeroForOneOnInflow,
            int256(_amount),
            sqrtPriceLimitX96,
            abi.encode(SwapCallbackData({tokenIn: gasTokenGlobalAddress}))
        ) returns (int256 amount0, int256 amount1) {
            return uint256(zeroForOneOnInflow ? amount1 : amount0);
        } catch (bytes memory) {
            _forceRevert();
            return 0;
        }
    }

    /**
     * @notice Swaps gas tokens from the given root chain to the branch chain
     * @param _amount amount of gas token to swap
     * @param _toChain chain to swap to
     */
    function _gasSwapOut(uint256 _amount, uint24 _toChain) internal returns (uint256, address) {
        //Get fromChain's Gas Pool Info
        (bool zeroForOneOnInflow, uint24 priceImpactPercentage, address gasTokenGlobalAddress, address poolAddress) =
            IPort(localPortAddress).getGasPoolInfo(_toChain);

        //Check if valid addresses
        if (gasTokenGlobalAddress == address(0) || poolAddress == address(0)) revert InvalidGasPool();

        //Save Gas Pool for future use
        if (!approvedGasPool[poolAddress]) approvedGasPool[poolAddress] = true;

        uint160 sqrtPriceLimitX96;
        {
            //Get sqrtPriceX96
            (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(poolAddress).slot0();

            // Calculate Price limit depending on pre-set price impact
            uint160 exactSqrtPriceImpact = (sqrtPriceX96 * (priceImpactPercentage / 2)) / GLOBAL_DIVISIONER;

            //Get limit
            sqrtPriceLimitX96 =
                zeroForOneOnInflow ? sqrtPriceX96 + exactSqrtPriceImpact : sqrtPriceX96 - exactSqrtPriceImpact;
        }

        //Swap imbalanced token as long as we haven't used the entire amountSpecified and haven't reached the price limit
        (int256 amount0, int256 amount1) = IUniswapV3Pool(poolAddress).swap(
            address(this),
            !zeroForOneOnInflow,
            int256(_amount),
            sqrtPriceLimitX96,
            abi.encode(SwapCallbackData({tokenIn: address(wrappedNativeToken)}))
        );

        return (uint256(!zeroForOneOnInflow ? amount1 : amount0), gasTokenGlobalAddress);
    }

    /**
     * @notice Manages gas costs of bridging from Root to a given Branch.
     * @param _toChain destination chain.
     */
    function _manageGasOut(uint24 _toChain) internal returns (uint128) {
        uint256 amountOut;
        address gasToken;
        uint256 _initialGas = initialGas;

        if (_toChain == localChainId) {
            //Transfer gasToBridgeOut Local Branch Bridge Agent if remote initiated call.
            if (_initialGas > 0) {
                address(wrappedNativeToken).safeTransfer(getBranchBridgeAgent[localChainId], userFeeInfo.gasToBridgeOut);
            }

            return uint128(userFeeInfo.gasToBridgeOut);
        }

        if (_initialGas > 0) {
            if (userFeeInfo.gasToBridgeOut <= MIN_FALLBACK_RESERVE * tx.gasprice) revert InsufficientGasForFees();
            (amountOut, gasToken) = _gasSwapOut(userFeeInfo.gasToBridgeOut, _toChain);
        } else {
            if (msg.value <= MIN_FALLBACK_RESERVE * tx.gasprice) revert InsufficientGasForFees();
            wrappedNativeToken.deposit{value: msg.value}();
            (amountOut, gasToken) = _gasSwapOut(msg.value, _toChain);
        }

        IPort(localPortAddress).burn(address(this), gasToken, amountOut, _toChain);
        return amountOut.toUint128();
    }

    /*///////////////////////////////////////////////////////////////
                    ANYCALL INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal function performs call to AnycallProxy Contract for cross-chain messaging.
    function _performCall(bytes memory _calldata, uint256 _toChain) internal {
        address callee = getBranchBridgeAgent[_toChain];

        if (callee == address(0)) revert UnrecognizedBridgeAgent();

        if (_toChain != localChainId) {
            //Sends message to AnycallProxy
            IAnycallProxy(localAnyCallAddress).anyCall(
                callee, _calldata, _toChain, AnycallFlags.FLAG_ALLOW_FALLBACK_DST, ""
            );
        } else {
            //Execute locally
            IBranchBridgeAgent(callee).anyExecute(_calldata);
        }
    }

    /**
     * @notice Pays for the remote call execution gas. Demands that the user has enough gas to replenish gas for the anycall config contract or forces reversion.
     * @param _depositedGas available user gas to pay for execution.
     * @param _gasToBridgeOut amount of gas needed to bridge out.
     * @param _initialGas initial gas used by the transaction.
     * @param _fromChain chain remote action initiated from.
     */
    function _payExecutionGas(uint128 _depositedGas, uint128 _gasToBridgeOut, uint256 _initialGas, uint24 _fromChain)
        internal
    {
        //reset initial remote execution gas and remote execution fee information
        delete(initialGas);
        delete(userFeeInfo);

        if (_fromChain == localChainId) return;

        //Get Available Gas
        uint256 availableGas = _depositedGas - _gasToBridgeOut;

        //Get Root Environment Execution Cost
        uint256 minExecCost = tx.gasprice * (MIN_EXECUTION_OVERHEAD + _initialGas - gasleft());

        //Check if sufficient balance
        if (minExecCost > availableGas) {
            _forceRevert();
            return;
        }

        //Replenish Gas
        _replenishGas(minExecCost);

        //Account for excess gas
        accumulatedFees += availableGas - minExecCost;
    }

    /**
     * @notice Updates the user deposit with the amount of gas needed to pay for the fallback function execution.
     * @param _settlementNonce nonce of the failed settlement
     * @param _initialGas initial gas available for this transaction
     */
    function _payFallbackGas(uint32 _settlementNonce, uint256 _initialGas) internal virtual {
        //Save gasleft
        uint256 gasLeft = gasleft();

        //Get Branch Environment Execution Cost
        uint256 minExecCost = tx.gasprice * (MIN_FALLBACK_RESERVE + _initialGas - gasLeft);

        //Check if sufficient balance
        if (minExecCost > getSettlement[_settlementNonce].gasToBridgeOut) {
            _forceRevert();
            return;
        }

        //Update user deposit reverts if not enough gas
        getSettlement[_settlementNonce].gasToBridgeOut -= minExecCost.toUint128();
    }

    function _replenishGas(uint256 _executionGasSpent) internal {
        //Unwrap Gas
        wrappedNativeToken.withdraw(_executionGasSpent);
        IAnycallConfig(IAnycallProxy(localAnyCallAddress).config()).deposit{value: _executionGasSpent}(address(this));
    }

    /// @notice Internal function that return 'from' address and 'fromChain' Id by performing an external call to AnycallExecutor Context.
    function _getContext() internal view returns (address from, uint256 fromChainId) {
        (from, fromChainId,) = IAnycallExecutor(localAnyCallExecutorAddress).context();
    }

    /// @inheritdoc IApp
    function anyExecute(bytes calldata data)
        external
        virtual
        requiresExecutor
        returns (bool success, bytes memory result)
    {
        //Get Initial Gas Checkpoint
        uint256 _initialGas = gasleft();

        uint24 fromChainId;

        UserFeeInfo memory _userFeeInfo;

        if (localAnyCallExecutorAddress == msg.sender) {
            //Save initial gas
            initialGas = _initialGas;

            //Get fromChainId from AnyExecutor Context
            (, uint256 _fromChainId) = _getContext();

            //Save fromChainId
            fromChainId = _fromChainId.toUint24();

            //Swap in all deposited Gas
            _userFeeInfo.depositedGas = _gasSwapIn(
                uint256(uint128(bytes16(data[data.length - PARAMS_GAS_IN:data.length - PARAMS_GAS_OUT]))), fromChainId
            ).toUint128();

            //Save Gas to Swap out to destination chain
            _userFeeInfo.gasToBridgeOut = uint128(bytes16(data[data.length - PARAMS_GAS_OUT:data.length]));
        } else {
            //Local Chain initiated call
            fromChainId = localChainId;

            //Save depositedGas
            _userFeeInfo.depositedGas = uint128(bytes16(data[data.length - 32:data.length - 16]));

            //Save Gas to Swap out to destination chain
            _userFeeInfo.gasToBridgeOut = _userFeeInfo.depositedGas;
        }

        if (_userFeeInfo.depositedGas < _userFeeInfo.gasToBridgeOut) {
            _forceRevert();
            //Return true to avoid triggering anyFallback in case of `_forceRevert()` failure
            return (true, "Not enough gas to bridge out");
        }

        //Store User Fee Info
        userFeeInfo = _userFeeInfo;

        //Read Bridge Agent Action Flag attached from cross-chain message header.
        bytes1 flag = data[0];

        //DEPOSIT FLAG: 0 (System request / response)
        if (flag == 0x00) {
            //Get nonce
            uint32 nonce = uint32(bytes4(data[PARAMS_START:PARAMS_TKN_START]));

            //Check if tx has already been executed
            if (executionHistory[fromChainId][nonce]) {
                _forceRevert();
                //Return true to avoid triggering anyFallback in case of `_forceRevert()` failure
                return (true, "already executed tx");
            }

            //Try to execute remote request
            try RootBridgeAgentExecutor(bridgeAgentExecutorAddress).executeSystemRequest(
                localRouterAddress, data, fromChainId
            ) returns (bool, bytes memory res) {
                (success, result) = (true, res);
            } catch (bytes memory reason) {
                //Interaction failure trigger fallback
                (success, result) = (false, reason);
            }

            //Update tx state as executed
            executionHistory[fromChainId][nonce] = true;

            //DEPOSIT FLAG: 1 (Call without Deposit)
        } else if (flag == 0x01) {
            //Get Deposit Nonce
            uint32 nonce = uint32(bytes4(data[PARAMS_START:PARAMS_TKN_START]));

            //Check if tx has already been executed
            if (executionHistory[fromChainId][nonce]) {
                _forceRevert();
                //Return true to avoid triggering anyFallback in case of `_forceRevert()` failure
                return (true, "already executed tx");
            }

            //Try to execute remote request
            try RootBridgeAgentExecutor(bridgeAgentExecutorAddress).executeNoDeposit(
                localRouterAddress, data, fromChainId
            ) returns (bool, bytes memory res) {
                (success, result) = (true, res);
            } catch (bytes memory reason) {
                //No new asset deposit no need to trigger fallback
                (success, result) = (true, reason);
            }

            //Update tx state as executed
            executionHistory[fromChainId][nonce] = true;

            //DEPOSIT FLAG: 2 (Call with Deposit)
        } else if (flag == 0x02) {
            //Get Deposit Nonce
            uint32 nonce = uint32(bytes4(data[PARAMS_START:PARAMS_TKN_START]));

            //Check if tx has already been executed
            if (executionHistory[fromChainId][nonce]) {
                _forceRevert();
                //Return true to avoid triggering anyFallback in case of `_forceRevert()` failure
                return (true, "already executed tx");
            }

            //Try to execute remote request
            try RootBridgeAgentExecutor(bridgeAgentExecutorAddress).executeWithDeposit(
                localRouterAddress, data, fromChainId
            ) returns (bool, bytes memory res) {
                (success, result) = (true, res);
            } catch (bytes memory reason) {
                result = reason;
            }

            //Update tx state as executed
            executionHistory[fromChainId][nonce] = true;

            //DEPOSIT FLAG: 3 (Call with multiple asset Deposit)
        } else if (flag == 0x03) {
            //Get deposit nonce
            uint32 nonce = uint32(bytes4(data[2:6]));

            //Check if tx has already been executed
            if (executionHistory[fromChainId][nonce]) {
                _forceRevert();
                //Return true to avoid triggering anyFallback in case of `_forceRevert()` failure
                return (true, "already executed tx");
            }

            //Try to execute remote request
            try RootBridgeAgentExecutor(bridgeAgentExecutorAddress).executeWithDepositMultiple(
                localRouterAddress, data, fromChainId
            ) returns (bool, bytes memory res) {
                (success, result) = (true, res);
            } catch (bytes memory reason) {
                result = reason;
            }

            //Update tx state as executed
            executionHistory[fromChainId][nonce] = true;

            //DEPOSIT FLAG: 4 (Call without Deposit + msg.sender)
        } else if (flag == 0x04) {
            //Get deposit nonce associated with request being processed
            uint32 nonce = uint32(bytes4(data[PARAMS_START_SIGNED:25]));

            //Check if tx has already been executed
            if (executionHistory[fromChainId][nonce]) {
                _forceRevert();
                //Return true to avoid triggering anyFallback in case of `_forceRevert()` failure
                return (true, "already executed tx");
            }

            //Get User Virtual Account
            VirtualAccount userAccount = IPort(localPortAddress).fetchVirtualAccount(
                address(uint160(bytes20(data[PARAMS_START:PARAMS_START_SIGNED])))
            );

            //Toggle Router Virtual Account use for tx execution
            IPort(localPortAddress).toggleVirtualAccountApproved(userAccount, localRouterAddress);

            //Try to execute remote request
            try RootBridgeAgentExecutor(bridgeAgentExecutorAddress).executeSignedNoDeposit(
                address(userAccount), localRouterAddress, data, fromChainId
            ) returns (bool, bytes memory res) {
                (success, result) = (true, res);
            } catch (bytes memory reason) {
                //No new asset deposit no need to trigger fallback
                (success, result) = (true, reason);
            }

            //Toggle Router Virtual Account use for tx execution
            IPort(localPortAddress).toggleVirtualAccountApproved(userAccount, localRouterAddress);

            //Update tx state as executed
            executionHistory[fromChainId][nonce] = true;

            //DEPOSIT FLAG: 5 (Call with Deposit + msg.sender)
        } else if (flag == 0x05) {
            //Get deposit nonce associated with request being processed
            uint32 nonce = uint32(bytes4(data[PARAMS_START_SIGNED:25]));

            //Check if tx has already been executed
            if (executionHistory[fromChainId][nonce]) {
                _forceRevert();
                //Return true to avoid triggering anyFallback in case of `_forceRevert()` failure
                return (true, "already executed tx");
            }

            //Get User Virtual Account
            VirtualAccount userAccount = IPort(localPortAddress).fetchVirtualAccount(
                address(uint160(bytes20(data[PARAMS_START:PARAMS_START_SIGNED])))
            );

            //Toggle Router Virtual Account use for tx execution
            IPort(localPortAddress).toggleVirtualAccountApproved(userAccount, localRouterAddress);

            //Try to execute remote request
            try RootBridgeAgentExecutor(bridgeAgentExecutorAddress).executeSignedWithDeposit(
                address(userAccount), localRouterAddress, data, fromChainId
            ) returns (bool, bytes memory res) {
                (success, result) = (true, res);
            } catch (bytes memory reason) {
                result = reason;
            }

            //Toggle Router Virtual Account use for tx execution
            IPort(localPortAddress).toggleVirtualAccountApproved(userAccount, localRouterAddress);

            //Update tx state as executed
            executionHistory[fromChainId][nonce] = true;

            //DEPOSIT FLAG: 6 (Call with multiple asset Deposit + msg.sender)
        } else if (flag == 0x06) {
            //Get nonce
            uint32 nonce = uint32(bytes4(data[PARAMS_START_SIGNED:25]));

            //Check if tx has already been executed
            if (executionHistory[fromChainId][nonce]) {
                _forceRevert();
                //Return true to avoid triggering anyFallback in case of `_forceRevert()` failure
                return (true, "already executed tx");
            }

            //Get User Virtual Account
            VirtualAccount userAccount = IPort(localPortAddress).fetchVirtualAccount(
                address(uint160(bytes20(data[PARAMS_START:PARAMS_START_SIGNED])))
            );

            //Toggle Router Virtual Account use for tx execution
            IPort(localPortAddress).toggleVirtualAccountApproved(userAccount, localRouterAddress);

            //Try to execute remote request
            try RootBridgeAgentExecutor(bridgeAgentExecutorAddress).executeSignedWithDepositMultiple(
                address(userAccount), localRouterAddress, data, fromChainId
            ) returns (bool, bytes memory res) {
                (success, result) = (true, res);
            } catch (bytes memory reason) {
                result = reason;
            }

            //Toggle Router Virtual Account use for tx execution
            IPort(localPortAddress).toggleVirtualAccountApproved(userAccount, localRouterAddress);

            //Update tx state as executed
            executionHistory[fromChainId][nonce] = true;

            /// DEPOSIT FLAG: 7 (retrySettlement)
        } else if (flag == 0x07) {
            //Get nonce
            uint32 nonce = uint32(bytes4(data[1:5]));

            //Check if tx has already been executed
            if (executionHistory[fromChainId][nonce]) {
                _forceRevert();
                //Return true to avoid triggering anyFallback in case of `_forceRevert()` failure
                return (true, "already executed tx");
            }

            //Try to execute remote request
            try RootBridgeAgentExecutor(bridgeAgentExecutorAddress).executeRetrySettlement(uint32(bytes4(data[5:9])))
            returns (bool, bytes memory res) {
                (success, result) = (true, res);
            } catch (bytes memory reason) {
                result = reason;
            }

            //Update tx state as executed
            executionHistory[fromChainId][nonce] = true;

            /// DEPOSIT FLAG: 8 (retrieveDeposit)
        } else if (flag == 0x08) {
            //Get nonce
            uint32 nonce = uint32(bytes4(data[1:5]));

            //Check if tx has already been executed
            if (!executionHistory[fromChainId][uint32(bytes4(data[1:5]))]) {
                //Toggle Nonce as executed
                executionHistory[fromChainId][nonce] = true;

                //Retry failed fallback
                (success, result) = (false, "");
            } else {
                _forceRevert();
                //Return true to avoid triggering anyFallback in case of `_forceRevert()` failure
                return (true, "already executed tx");
            }

            //Unrecognized Function Selector
        } else {
            //Zero out gas after use if remote call
            if (initialGas > 0) {
                _payExecutionGas(userFeeInfo.depositedGas, userFeeInfo.gasToBridgeOut, _initialGas, fromChainId);
            }

            return (false, "unknown selector");
        }

        emit LogCallin(flag, data, fromChainId);

        //Zero out gas after use if remote call
        if (initialGas > 0) {
            _payExecutionGas(userFeeInfo.depositedGas, userFeeInfo.gasToBridgeOut, _initialGas, fromChainId);
        }
    }

    /// @inheritdoc IApp
    function anyFallback(bytes calldata data)
        external
        virtual
        requiresExecutor
        returns (bool success, bytes memory result)
    {
        //Get Initial Gas Checkpoint
        uint256 _initialGas = gasleft();

        //Get fromChain
        (, uint256 _fromChainId) = _getContext();
        uint24 fromChainId = _fromChainId.toUint24();

        //Save Flag
        bytes1 flag = data[0];

        //Deposit nonce
        uint32 _settlementNonce;

        /// SETTLEMENT FLAG: 1 (single asset settlement)
        if (flag == 0x00) {
            _settlementNonce = uint32(bytes4(data[PARAMS_START_SIGNED:25]));
            _reopenSettlemment(_settlementNonce);

            /// SETTLEMENT FLAG: 1 (single asset settlement)
        } else if (flag == 0x01) {
            _settlementNonce = uint32(bytes4(data[PARAMS_START_SIGNED:25]));
            _reopenSettlemment(_settlementNonce);

            /// SETTLEMENT FLAG: 2 (multiple asset settlement)
        } else if (flag == 0x02) {
            _settlementNonce = uint32(bytes4(data[22:26]));
            _reopenSettlemment(_settlementNonce);
        }
        emit LogCalloutFail(flag, data, fromChainId);

        _payFallbackGas(_settlementNonce, _initialGas);

        return (true, "");
    }

    /// @inheritdoc IRootBridgeAgent
    function depositGasAnycallConfig() external payable {
        //Deposit Gas
        _replenishGas(msg.value);
    }

    /// @inheritdoc IRootBridgeAgent
    function forceRevert() external requiresLocalBranchBridgeAgent {
        _forceRevert();
    }

    /**
     * @notice Reverts the current transaction with a "no enough budget" message.
     * @dev This function is used to revert the current transaction with a "no enough budget" message.
     */
    function _forceRevert() internal {
        if (initialGas == 0) revert GasErrorOrRepeatedTx();

        IAnycallConfig anycallConfig = IAnycallConfig(IAnycallProxy(localAnyCallAddress).config());
        uint256 executionBudget = anycallConfig.executionBudget(address(this));

        // Withdraw all execution gas budget from anycall for tx to revert with "no enough budget"
        if (executionBudget > 0) try anycallConfig.withdraw(executionBudget) {} catch {}
    }

    /*///////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRootBridgeAgent
    function approveBranchBridgeAgent(uint256 _branchChainId) external requiresManager {
        if (getBranchBridgeAgent[_branchChainId] != address(0)) revert AlreadyAddedBridgeAgent();
        isBranchBridgeAgentAllowed[_branchChainId] = true;
    }

    /// @inheritdoc IRootBridgeAgent
    function syncBranchBridgeAgent(address _newBranchBridgeAgent, uint24 _branchChainId) external requiresPort {
        getBranchBridgeAgent[_branchChainId] = _newBranchBridgeAgent;
    }

    /// @inheritdoc IRootBridgeAgent
    function sweep() external {
        if (msg.sender != daoAddress) revert NotDao();
        uint256 _accumulatedFees = accumulatedFees - 1;
        accumulatedFees = 1;
        SafeTransferLib.safeTransferETH(daoAddress, _accumulatedFees);
    }

    /*///////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    uint256 internal _unlocked = 1;

    /// @notice Modifier for a simple re-entrancy check.
    modifier lock() {
        require(_unlocked == 1);
        _unlocked = 2;
        _;
        _unlocked = 1;
    }

    /// @notice Modifier verifies the caller is the Anycall Executor or Local Branch Bridge Agent.
    modifier requiresExecutor() {
        _requiresExecutor();
        _;
    }

    /// @notice Verifies the caller is the Anycall Executor or Local Branch Bridge Agent. Internal function used in modifier to reduce contract bytesize.
    function _requiresExecutor() internal view {
        if (msg.sender == getBranchBridgeAgent[localChainId]) return;

        if (msg.sender != localAnyCallExecutorAddress) revert AnycallUnauthorizedCaller();
        (address from, uint256 fromChainId,) = IAnycallExecutor(localAnyCallExecutorAddress).context();
        if (getBranchBridgeAgent[fromChainId] != from) revert AnycallUnauthorizedCaller();
    }

    /// @notice Modifier that verifies msg sender is the Bridge Agent's Router
    modifier requiresRouter() {
        _requiresRouter();
        _;
    }

    /// @notice Internal function to verify msg sender is Bridge Agent's Router. Reuse to reduce contract bytesize.
    function _requiresRouter() internal view {
        if (msg.sender != localRouterAddress) revert UnrecognizedCallerNotRouter();
    }

    /// @notice Modifier that verifies msg sender is Bridge Agent Executor.
    modifier requiresAgentExecutor() {
        if (msg.sender != bridgeAgentExecutorAddress) revert UnrecognizedExecutor();
        _;
    }

    /// @notice Modifier that verifies msg sender is Local Branch Bridge Agent.
    modifier requiresLocalBranchBridgeAgent() {
        if (msg.sender != getBranchBridgeAgent[localChainId]) {
            revert UnrecognizedExecutor();
        }
        _;
    }

    /// @notice Modifier that verifies msg sender is the Local Port.
    modifier requiresPort() {
        if (msg.sender != localPortAddress) revert UnrecognizedPort();
        _;
    }

    /// @notice Modifier that verifies msg sender is the Bridge Agent's Manager.
    modifier requiresManager() {
        if (msg.sender != IPort(localPortAddress).getBridgeAgentManager(address(this))) {
            revert UnrecognizedBridgeAgentManager();
        }
        _;
    }

    fallback() external payable {}
}
