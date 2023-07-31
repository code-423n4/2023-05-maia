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
import {IApp, IBranchBridgeAgent} from "./interfaces/IBranchBridgeAgent.sol";
import {IBranchRouter as IRouter} from "./interfaces/IBranchRouter.sol";
import {IBranchPort as IPort} from "./interfaces/IBranchPort.sol";

import {ERC20hTokenBranch as ERC20hToken} from "./token/ERC20hTokenBranch.sol";
import {BranchBridgeAgentExecutor, DeployBranchBridgeAgentExecutor} from "./BranchBridgeAgentExecutor.sol";
import {
    Deposit,
    DepositStatus,
    DepositInput,
    DepositMultipleInput,
    DepositParams,
    DepositMultipleParams,
    SettlementParams,
    SettlementMultipleParams
} from "./interfaces/IBranchBridgeAgent.sol";

/// @title Library for Branch Bridge Agent Deployment
library DeployBranchBridgeAgent {
    function deploy(
        WETH9 _wrappedNativeToken,
        uint256 _rootChainId,
        uint256 _localChainId,
        address _rootBridgeAgentAddress,
        address _localAnyCallAddress,
        address _localAnyCallExecutorAddress,
        address _localRouterAddress,
        address _localPortAddress
    ) external returns (BranchBridgeAgent) {
        return new BranchBridgeAgent(
            _wrappedNativeToken,
            _rootChainId,
            _localChainId,
            _rootBridgeAgentAddress,
            _localAnyCallAddress,
            _localAnyCallExecutorAddress,
            _localRouterAddress,
            _localPortAddress
        );
    }
}

/// @title Branch Bridge Agent Contract
contract BranchBridgeAgent is IBranchBridgeAgent {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;

    /*///////////////////////////////////////////////////////////////
                            ENCODING CONSTS
    //////////////////////////////////////////////////////////////*/

    /// AnyExec Decode Consts

    uint8 internal constant PARAMS_START = 1;

    uint8 internal constant PARAMS_START_SIGNED = 21;

    uint8 internal constant PARAMS_ENTRY_SIZE = 32;

    uint8 internal constant PARAMS_GAS_OUT = 16;

    /// ClearTokens Decode Consts

    uint8 internal constant PARAMS_TKN_START = 5;

    uint8 internal constant PARAMS_AMT_OFFSET = 64;

    uint8 internal constant PARAMS_DEPOSIT_OFFSET = 96;

    /*///////////////////////////////////////////////////////////////
                        BRIDGE AGENT STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Chain Id for Root Chain where liqudity is virtualized(e.g. 4).
    uint256 public immutable rootChainId;

    /// @notice Chain Id for Local Chain.
    uint256 public immutable localChainId;

    /// @notice Address for Local Wrapped Native Token.
    WETH9 public immutable wrappedNativeToken;

    /// @notice Address for Bridge Agent who processes requests submitted for the Root Router Address where cross-chain requests are executed in the Root Chain.
    address public immutable rootBridgeAgentAddress;

    /// @notice Address for Local AnycallV7 Proxy Address where cross-chain requests are sent to the Root Chain Router.
    address public immutable localAnyCallAddress;

    /// @notice Address for Local Anyexec Address where cross-chain requests from the Root Chain Router are received locally.
    address public immutable localAnyCallExecutorAddress;

    /// @notice Address for Local Router used for custom actions for different hApps.
    address public immutable localRouterAddress;

    /// @notice Address for Local Port Address where funds deposited from this chain are kept, managed and supplied to different Port Strategies.
    address public immutable localPortAddress;

    address public bridgeAgentExecutorAddress;

    /*///////////////////////////////////////////////////////////////
                        DEPOSITS STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit nonce used for identifying transaction.
    uint32 public depositNonce;

    /// @notice Mapping from Pending deposits hash to Deposit Struct.
    mapping(uint32 => Deposit) public getDeposit;

    /*///////////////////////////////////////////////////////////////
                            EXECUTOR STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice If true, bridge agent has already served a request with this nonce from  a given chain. Chain -> Nonce -> Bool
    mapping(uint32 => bool) public executionHistory;

    /*///////////////////////////////////////////////////////////////
                        GAS MANAGEMENT STATE
    //////////////////////////////////////////////////////////////*/

    uint256 public remoteCallDepositedGas;

    uint256 internal constant MIN_FALLBACK_RESERVE = 185_000; // 100_000 for anycall + 85_000 fallback execution overhead
    uint256 internal constant MIN_EXECUTION_OVERHEAD = 160_000; // 100_000 for anycall + 35_000 Pre 1st Gas Checkpoint Execution + 25_000 Post last Gas Checkpoint Executions
    uint256 internal constant TRANSFER_OVERHEAD = 24_000;

    constructor(
        WETH9 _wrappedNativeToken,
        uint256 _rootChainId,
        uint256 _localChainId,
        address _rootBridgeAgentAddress,
        address _localAnyCallAddress,
        address _localAnyCallExecutorAddress,
        address _localRouterAddress,
        address _localPortAddress
    ) {
        require(_rootBridgeAgentAddress != address(0), "Root Bridge Agent Address cannot be the zero address.");
        require(_localAnyCallAddress != address(0), "AnyCall Address cannot be the zero address.");
        require(_localAnyCallExecutorAddress != address(0), "AnyCall Executor Address cannot be the zero address.");
        require(_localRouterAddress != address(0), "Local Router Address cannot be the zero address.");
        require(_localPortAddress != address(0), "Local Port Address cannot be the zero address.");

        wrappedNativeToken = _wrappedNativeToken;
        localChainId = _localChainId;
        rootChainId = _rootChainId;
        rootBridgeAgentAddress = _rootBridgeAgentAddress;
        localAnyCallAddress = _localAnyCallAddress;
        localAnyCallExecutorAddress = _localAnyCallExecutorAddress;
        localRouterAddress = _localRouterAddress;
        localPortAddress = _localPortAddress;
        bridgeAgentExecutorAddress = DeployBranchBridgeAgentExecutor.deploy();
        depositNonce = 1;
    }

    /*///////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBranchBridgeAgent
    function getDepositEntry(uint32 _depositNonce) external view returns (Deposit memory) {
        return getDeposit[_depositNonce];
    }

    /*///////////////////////////////////////////////////////////////
                        USER EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBranchBridgeAgent
    function callOut(bytes calldata _params, uint128 _remoteExecutionGas) external payable lock requiresFallbackGas {
        //Wrap the gas allocated for omnichain execution.
        wrappedNativeToken.deposit{value: msg.value}();

        //Perform Call without deposit
        _callOut(msg.sender, _params, msg.value.toUint128(), _remoteExecutionGas);
    }

    /// @inheritdoc IBranchBridgeAgent
    function callOutAndBridge(bytes calldata _params, DepositInput memory _dParams, uint128 _remoteExecutionGas)
        external
        payable
        lock
        requiresFallbackGas
    {
        //Wrap the gas allocated for omnichain execution.
        wrappedNativeToken.deposit{value: msg.value}();

        //Perform Call with deposit
        _callOutAndBridge(msg.sender, _params, _dParams, msg.value.toUint128(), _remoteExecutionGas);
    }

    /// @inheritdoc IBranchBridgeAgent
    function callOutAndBridgeMultiple(
        bytes calldata _params,
        DepositMultipleInput memory _dParams,
        uint128 _remoteExecutionGas
    ) external payable lock requiresFallbackGas {
        //Wrap the gas allocated for omnichain execution.
        wrappedNativeToken.deposit{value: msg.value}();

        //Perform Call with multiple deposits
        _callOutAndBridgeMultiple(msg.sender, _params, _dParams, msg.value.toUint128(), _remoteExecutionGas);
    }

    /// @inheritdoc IBranchBridgeAgent
    function callOutSigned(bytes calldata _params, uint128 _remoteExecutionGas)
        external
        payable
        lock
        requiresFallbackGas
    {
        //Encode Data for cross-chain call.
        bytes memory packedData = abi.encodePacked(
            bytes1(0x04), msg.sender, depositNonce, _params, msg.value.toUint128(), _remoteExecutionGas
        );

        //Wrap the gas allocated for omnichain execution.
        wrappedNativeToken.deposit{value: msg.value}();

        //Perform Signed Call without deposit
        _noDepositCall(msg.sender, packedData, msg.value.toUint128());
    }

    /// @inheritdoc IBranchBridgeAgent
    function callOutSignedAndBridge(bytes calldata _params, DepositInput memory _dParams, uint128 _remoteExecutionGas)
        external
        payable
        lock
        requiresFallbackGas
    {
        //Encode Data for cross-chain call.
        bytes memory packedData = abi.encodePacked(
            bytes1(0x05),
            msg.sender,
            depositNonce,
            _dParams.hToken,
            _dParams.token,
            _dParams.amount,
            _normalizeDecimals(_dParams.deposit, ERC20(_dParams.token).decimals()),
            _dParams.toChain,
            _params,
            msg.value.toUint128(),
            _remoteExecutionGas
        );

        //Wrap the gas allocated for omnichain execution.
        wrappedNativeToken.deposit{value: msg.value}();

        //Create Deposit and Send Cross-Chain request
        _depositAndCall(
            msg.sender,
            packedData,
            _dParams.hToken,
            _dParams.token,
            _dParams.amount,
            _dParams.deposit,
            msg.value.toUint128()
        );
    }

    /// @inheritdoc IBranchBridgeAgent
    function callOutSignedAndBridgeMultiple(
        bytes calldata _params,
        DepositMultipleInput memory _dParams,
        uint128 _remoteExecutionGas
    ) external payable lock requiresFallbackGas {
        //Normalize Deposits
        uint256[] memory _deposits = new uint256[](_dParams.hTokens.length);

        for (uint256 i = 0; i < _dParams.hTokens.length; i++) {
            _deposits[i] = _normalizeDecimals(_dParams.deposits[i], ERC20(_dParams.tokens[i]).decimals());
        }

        //Encode Data for cross-chain call.
        bytes memory packedData = abi.encodePacked(
            bytes1(0x06),
            msg.sender,
            uint8(_dParams.hTokens.length),
            depositNonce,
            _dParams.hTokens,
            _dParams.tokens,
            _dParams.amounts,
            _deposits,
            _dParams.toChain,
            _params,
            msg.value.toUint128(),
            _remoteExecutionGas
        );

        //Wrap the gas allocated for omnichain execution.
        wrappedNativeToken.deposit{value: msg.value}();

        //Create Deposit and Send Cross-Chain request
        _depositAndCallMultiple(
            msg.sender,
            packedData,
            _dParams.hTokens,
            _dParams.tokens,
            _dParams.amounts,
            _dParams.deposits,
            msg.value.toUint128()
        );
    }

    /// @inheritdoc IBranchBridgeAgent
    function retryDeposit(
        bool _isSigned,
        uint32 _depositNonce,
        bytes calldata _params,
        uint128 _remoteExecutionGas,
        uint24 _toChain
    ) external payable lock requiresFallbackGas {
        //Check if deposit belongs to message sender
        if (getDeposit[_depositNonce].owner != msg.sender) revert NotDepositOwner();

        //Encode Data for cross-chain call.
        bytes memory packedData;

        if (uint8(getDeposit[_depositNonce].hTokens.length) == 1) {
            if (_isSigned) {
                packedData = abi.encodePacked(
                    bytes1(0x05),
                    msg.sender,
                    _depositNonce,
                    getDeposit[_depositNonce].hTokens[0],
                    getDeposit[_depositNonce].tokens[0],
                    getDeposit[_depositNonce].amounts[0],
                    _normalizeDecimals(
                        getDeposit[_depositNonce].deposits[0], ERC20(getDeposit[_depositNonce].tokens[0]).decimals()
                    ),
                    _toChain,
                    _params,
                    msg.value.toUint128(),
                    _remoteExecutionGas
                );
            } else {
                packedData = abi.encodePacked(
                    bytes1(0x02),
                    _depositNonce,
                    getDeposit[_depositNonce].hTokens[0],
                    getDeposit[_depositNonce].tokens[0],
                    getDeposit[_depositNonce].amounts[0],
                    _normalizeDecimals(
                        getDeposit[_depositNonce].deposits[0], ERC20(getDeposit[_depositNonce].tokens[0]).decimals()
                    ),
                    _toChain,
                    _params,
                    msg.value.toUint128(),
                    _remoteExecutionGas
                );
            }
        } else if (uint8(getDeposit[_depositNonce].hTokens.length) > 1) {
            //Nonce
            uint32 nonce = _depositNonce;

            if (_isSigned) {
                packedData = abi.encodePacked(
                    bytes1(0x06),
                    msg.sender,
                    uint8(getDeposit[_depositNonce].hTokens.length),
                    nonce,
                    getDeposit[nonce].hTokens,
                    getDeposit[nonce].tokens,
                    getDeposit[nonce].amounts,
                    _normalizeDecimalsMultiple(getDeposit[nonce].deposits, getDeposit[nonce].tokens),
                    _toChain,
                    _params,
                    msg.value.toUint128(),
                    _remoteExecutionGas
                );
            } else {
                packedData = abi.encodePacked(
                    bytes1(0x03),
                    uint8(getDeposit[nonce].hTokens.length),
                    _depositNonce,
                    getDeposit[nonce].hTokens,
                    getDeposit[nonce].tokens,
                    getDeposit[nonce].amounts,
                    _normalizeDecimalsMultiple(getDeposit[nonce].deposits, getDeposit[nonce].tokens),
                    _toChain,
                    _params,
                    msg.value.toUint128(),
                    _remoteExecutionGas
                );
            }
        }

        //Wrap the gas allocated for omnichain execution.
        wrappedNativeToken.deposit{value: msg.value}();

        //Deposit Gas to Port
        _depositGas(msg.value.toUint128());

        //Ensure success Status
        getDeposit[_depositNonce].status = DepositStatus.Success;

        //Update Deposited Gas
        getDeposit[_depositNonce].depositedGas = msg.value.toUint128();

        //Perform Call
        _performCall(packedData);
    }

    /// @inheritdoc IBranchBridgeAgent
    function retrySettlement(uint32 _settlementNonce, uint128 _gasToBoostSettlement)
        external
        payable
        lock
        requiresFallbackGas
    {
        //Encode Data for cross-chain call.
        bytes memory packedData = abi.encodePacked(
            bytes1(0x07), depositNonce++, _settlementNonce, msg.value.toUint128(), _gasToBoostSettlement
        );
        //Update State and Perform Call
        _sendRetrieveOrRetry(packedData);
    }

    /// @inheritdoc IBranchBridgeAgent
    function retrieveDeposit(uint32 _depositNonce) external payable lock requiresFallbackGas {
        //Encode Data for cross-chain call.
        bytes memory packedData = abi.encodePacked(bytes1(0x08), _depositNonce, msg.value.toUint128(), uint128(0));

        //Update State and Perform Call
        _sendRetrieveOrRetry(packedData);
    }

    function _sendRetrieveOrRetry(bytes memory _data) internal {
        //Deposit Gas for call.
        _createGasDeposit(msg.sender, msg.value.toUint128());

        //Perform Call
        _performCall(_data);
    }

    /// @inheritdoc IBranchBridgeAgent
    function redeemDeposit(uint32 _depositNonce) external lock {
        //Update Deposit
        if (getDeposit[_depositNonce].status != DepositStatus.Failed) {
            revert DepositRedeemUnavailable();
        }
        _redeemDeposit(_depositNonce);
    }

    /*///////////////////////////////////////////////////////////////
                    BRANCH ROUTER EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBranchBridgeAgent
    function performSystemCallOut(
        address _depositor,
        bytes calldata _params,
        uint128 _gasToBridgeOut,
        uint128 _remoteExecutionGas
    ) external payable lock requiresRouter {
        //Get remote call execution deposited gas.
        (uint128 gasToBridgeOut, bool isRemote) =
            (remoteCallDepositedGas > 0 ? (_gasToBridgeOut, true) : (msg.value.toUint128(), false));

        //Wrap the gas allocated for omnichain execution.
        if (!isRemote && gasToBridgeOut > 0) wrappedNativeToken.deposit{value: msg.value}();

        //Check Fallback Gas
        _requiresFallbackGas(gasToBridgeOut);

        //Encode Data for cross-chain call.
        bytes memory packedData =
            abi.encodePacked(bytes1(0x00), depositNonce, _params, gasToBridgeOut, _remoteExecutionGas);

        //Perform Call
        _noDepositCall(_depositor, packedData, gasToBridgeOut);
    }

    /// @inheritdoc IBranchBridgeAgent
    function performCallOut(
        address _depositor,
        bytes calldata _params,
        uint128 _gasToBridgeOut,
        uint128 _remoteExecutionGas
    ) external payable lock requiresRouter {
        //Get remote call execution deposited gas.
        (uint128 gasToBridgeOut, bool isRemote) =
            (remoteCallDepositedGas > 0 ? (_gasToBridgeOut, true) : (msg.value.toUint128(), false));

        //Wrap the gas allocated for omnichain execution.
        if (!isRemote && gasToBridgeOut > 0) wrappedNativeToken.deposit{value: msg.value}();

        //Check Fallback Gas
        _requiresFallbackGas(gasToBridgeOut);

        //Perform Call
        _callOut(_depositor, _params, gasToBridgeOut, _remoteExecutionGas);
    }

    /// @inheritdoc IBranchBridgeAgent
    function performCallOutAndBridge(
        address _depositor,
        bytes calldata _params,
        DepositInput memory _dParams,
        uint128 _gasToBridgeOut,
        uint128 _remoteExecutionGas
    ) external payable lock requiresRouter {
        //Get remote call execution deposited gas.
        (uint128 gasToBridgeOut, bool isRemote) =
            (remoteCallDepositedGas > 0 ? (_gasToBridgeOut, true) : (msg.value.toUint128(), false));

        //Wrap the gas allocated for omnichain execution.
        if (!isRemote && gasToBridgeOut > 0) wrappedNativeToken.deposit{value: msg.value}();

        //Check Fallback Gas
        _requiresFallbackGas(gasToBridgeOut);

        //Perform Call
        _callOutAndBridge(_depositor, _params, _dParams, gasToBridgeOut, _remoteExecutionGas);
    }

    /// @inheritdoc IBranchBridgeAgent
    function performCallOutAndBridgeMultiple(
        address _depositor,
        bytes calldata _params,
        DepositMultipleInput memory _dParams,
        uint128 _gasToBridgeOut,
        uint128 _remoteExecutionGas
    ) external payable lock requiresRouter {
        //Get remote call execution deposited gas.
        (uint128 gasToBridgeOut, bool isRemote) =
            (remoteCallDepositedGas > 0 ? (_gasToBridgeOut, true) : (msg.value.toUint128(), false));

        //Wrap the gas allocated for omnichain execution.
        if (!isRemote && gasToBridgeOut > 0) wrappedNativeToken.deposit{value: msg.value}();

        //Check Fallback Gas
        _requiresFallbackGas(gasToBridgeOut);

        //Perform Call
        _callOutAndBridgeMultiple(_depositor, _params, _dParams, gasToBridgeOut, _remoteExecutionGas);
    }

    /*///////////////////////////////////////////////////////////////
                TOKEN MANAGEMENT EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBranchBridgeAgent
    function clearToken(address _recipient, address _hToken, address _token, uint256 _amount, uint256 _deposit)
        external
        requiresAgentExecutor
    {
        _clearToken(_recipient, _hToken, _token, _amount, _deposit);
    }

    /// @inheritdoc IBranchBridgeAgent
    function clearTokens(bytes calldata _sParams, address _recipient)
        external
        requiresAgentExecutor
        returns (SettlementMultipleParams memory)
    {
        //Parse Params
        uint8 numOfAssets = uint8(bytes1(_sParams[0]));
        uint32 nonce = uint32(bytes4(_sParams[PARAMS_START:PARAMS_TKN_START]));

        address[] memory _hTokens = new address[](numOfAssets);
        address[] memory _tokens = new address[](numOfAssets);
        uint256[] memory _amounts = new uint256[](numOfAssets);
        uint256[] memory _deposits = new uint256[](numOfAssets);

        //Transfer token to recipient
        for (uint256 i = 0; i < numOfAssets;) {
            //Parse Params
            _hTokens[i] = address(
                uint160(
                    bytes20(
                        bytes32(
                            _sParams[
                                PARAMS_TKN_START + (PARAMS_ENTRY_SIZE * i) + 12:
                                    PARAMS_TKN_START + (PARAMS_ENTRY_SIZE * (PARAMS_START + i))
                            ]
                        )
                    )
                )
            );
            _tokens[i] = address(
                uint160(
                    bytes20(
                        _sParams[
                            PARAMS_TKN_START + PARAMS_ENTRY_SIZE * uint16(i + numOfAssets) + 12:
                                PARAMS_TKN_START + PARAMS_ENTRY_SIZE * uint16(PARAMS_START + i + numOfAssets)
                        ]
                    )
                )
            );
            _amounts[i] = uint256(
                bytes32(
                    _sParams[
                        PARAMS_TKN_START + PARAMS_AMT_OFFSET * uint16(numOfAssets) + (PARAMS_ENTRY_SIZE * uint16(i)):
                            PARAMS_TKN_START + PARAMS_AMT_OFFSET * uint16(numOfAssets)
                                + PARAMS_ENTRY_SIZE * uint16(PARAMS_START + i)
                    ]
                )
            );
            _deposits[i] = uint256(
                bytes32(
                    _sParams[
                        PARAMS_TKN_START + PARAMS_DEPOSIT_OFFSET * uint16(numOfAssets) + (PARAMS_ENTRY_SIZE * uint16(i)):
                            PARAMS_TKN_START + PARAMS_DEPOSIT_OFFSET * uint16(numOfAssets)
                                + PARAMS_ENTRY_SIZE * uint16(PARAMS_START + i)
                    ]
                )
            );
            //Clear Tokens to destination
            if (_amounts[i] - _deposits[i] > 0) {
                IPort(localPortAddress).bridgeIn(_recipient, _hTokens[i], _amounts[i] - _deposits[i]);
            }

            if (_deposits[i] > 0) {
                IPort(localPortAddress).withdraw(_recipient, _tokens[i], _deposits[i]);
            }

            unchecked {
                ++i;
            }
        }

        return SettlementMultipleParams(numOfAssets, _recipient, nonce, _hTokens, _tokens, _amounts, _deposits);
    }

    /*///////////////////////////////////////////////////////////////
                LOCAL USER DEPOSIT INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to perform a call to the Root Omnichain Router without token deposit.
     *   @param _depositor address of the user that will deposit the funds.
     *   @param _params RLP enconded parameters to execute on the root chain.
     *   @param _gasToBridgeOut gas allocated for the cross-chain call.
     *   @param _remoteExecutionGas gas allocated for branch chain execution.
     *   @dev ACTION ID: 1 (Call without deposit)
     *
     */
    function _callOut(address _depositor, bytes calldata _params, uint128 _gasToBridgeOut, uint128 _remoteExecutionGas)
        internal
    {
        //Encode Data for cross-chain call.
        bytes memory packedData =
            abi.encodePacked(bytes1(0x01), depositNonce, _params, _gasToBridgeOut, _remoteExecutionGas);

        //Perform Call
        _noDepositCall(_depositor, packedData, _gasToBridgeOut);
    }

    /**
     * @notice Function to perform a call to the Root Omnichain Router while depositing a single asset.
     *   @param _depositor address of the user that will deposit the funds.
     *   @param _params RLP enconded parameters to execute on the root chain.
     *   @param _dParams additional token deposit parameters.
     *   @param _gasToBridgeOut gas allocated for the cross-chain call.
     *   @param _remoteExecutionGas gas allocated for branch chain execution.
     *   @dev ACTION ID: 2 (Call with single deposit)
     *
     */
    function _callOutAndBridge(
        address _depositor,
        bytes calldata _params,
        DepositInput memory _dParams,
        uint128 _gasToBridgeOut,
        uint128 _remoteExecutionGas
    ) internal {
        //Encode Data for cross-chain call.
        bytes memory packedData = abi.encodePacked(
            bytes1(0x02),
            depositNonce,
            _dParams.hToken,
            _dParams.token,
            _dParams.amount,
            _normalizeDecimals(_dParams.deposit, ERC20(_dParams.token).decimals()),
            _dParams.toChain,
            _params,
            _gasToBridgeOut,
            _remoteExecutionGas
        );

        //Create Deposit and Send Cross-Chain request
        _depositAndCall(
            _depositor, packedData, _dParams.hToken, _dParams.token, _dParams.amount, _dParams.deposit, _gasToBridgeOut
        );
    }

    /**
     * @notice Function to perform a call to the Root Omnichain Router while depositing two or more assets.
     *   @param _params RLP enconded parameters to execute on the root chain.
     *   @param _dParams additional token deposit parameters.
     *   @param _gasToBridgeOut gas allocated for the cross-chain call.
     *   @param _remoteExecutionGas gas allocated for branch chain execution.
     *   @dev ACTION ID: 3 (Call with multiple deposit)
     *
     */
    function _callOutAndBridgeMultiple(
        address _depositor,
        bytes calldata _params,
        DepositMultipleInput memory _dParams,
        uint128 _gasToBridgeOut,
        uint128 _remoteExecutionGas
    ) internal {
        //Normalize Deposits
        uint256[] memory deposits = new uint256[](_dParams.hTokens.length);

        for (uint256 i = 0; i < _dParams.hTokens.length; i++) {
            deposits[i] = _normalizeDecimals(_dParams.deposits[i], ERC20(_dParams.tokens[i]).decimals());
        }

        //Encode Data for cross-chain call.
        bytes memory packedData = abi.encodePacked(
            bytes1(0x03),
            uint8(_dParams.hTokens.length),
            depositNonce,
            _dParams.hTokens,
            _dParams.tokens,
            _dParams.amounts,
            deposits,
            _dParams.toChain,
            _params,
            _gasToBridgeOut,
            _remoteExecutionGas
        );

        //Create Deposit and Send Cross-Chain request
        _depositAndCallMultiple(
            _depositor,
            packedData,
            _dParams.hTokens,
            _dParams.tokens,
            _dParams.amounts,
            _dParams.deposits,
            _gasToBridgeOut
        );
    }

    /**
     * @notice Internal function to move assets from branch chain to root omnichain environment. Naive assets are deposited and hTokens are bridgedOut.
     *   @param _depositor token depositor.
     *   @param _data data to be sent to cross-chain messaging layer.
     *   @param _gasToBridgeOut gas allocated for the cross-chain call.
     *
     */
    function _noDepositCall(address _depositor, bytes memory _data, uint128 _gasToBridgeOut) internal {
        //Deposit Gas for call.
        _createGasDeposit(_depositor, _gasToBridgeOut);

        //Perform Call
        _performCall(_data);
    }

    /**
     * @notice Internal function to move assets from branch chain to root omnichain environment. Naive assets are deposited and hTokens are bridgedOut.
     *   @param _depositor token depositor.
     *   @param _data data to be sent to cross-chain messaging layer.
     *   @param _hToken Local Input hToken Address.
     *   @param _token Native / Underlying Token Address.
     *   @param _amount Amount of Local hTokens deposited for trade.
     *   @param _deposit Amount of native tokens deposited for trade.
     *   @param _gasToBridgeOut gas allocated for the cross-chain call.
     *
     */
    function _depositAndCall(
        address _depositor,
        bytes memory _data,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        uint128 _gasToBridgeOut
    ) internal {
        //Deposit and Store Info
        _createDepositSingle(_depositor, _hToken, _token, _amount, _deposit, _gasToBridgeOut);

        //Perform Call
        _performCall(_data);
    }

    /**
     * @dev Internal function to move assets from branch chain to root omnichain environment. Naive assets are deposited and hTokens are bridgedOut.
     *   @param _depositor token depositor.
     *   @param _data data to be sent to cross-chain messaging layer.
     *   @param _hTokens Local Input hToken Address.
     *   @param _tokens Native / Underlying Token Address.
     *   @param _amounts Amount of Local hTokens deposited for trade.
     *   @param _deposits  Amount of native tokens deposited for trade.
     *   @param _gasToBridgeOut gas allocated for the cross-chain call.
     *
     */
    function _depositAndCallMultiple(
        address _depositor,
        bytes memory _data,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        uint128 _gasToBridgeOut
    ) internal {
        //Validate Input
        if (
            _hTokens.length != _tokens.length || _tokens.length != _amounts.length
                || _amounts.length != _deposits.length
        ) revert InvalidInput();

        //Deposit and Store Info
        _createDepositMultiple(_depositor, _hTokens, _tokens, _amounts, _deposits, _gasToBridgeOut);

        //Perform Call
        _performCall(_data);
    }

    /**
     * @dev Function to create a pending deposit.
     *    @param _user user address.
     *    @param _gasToBridgeOut gas allocated for omnichain execution.
     *
     */
    function _createGasDeposit(address _user, uint128 _gasToBridgeOut) internal {
        //Deposit Gas to Port
        _depositGas(_gasToBridgeOut);

        // Update State
        getDeposit[_getAndIncrementDepositNonce()] = Deposit({
            owner: _user,
            hTokens: new address[](0),
            tokens: new address[](0),
            amounts: new uint256[](0),
            deposits: new uint256[](0),
            status: DepositStatus.Success,
            depositedGas: _gasToBridgeOut
        });
    }

    /**
     * @dev Function to create a pending deposit.
     *    @param _user user address.
     *    @param _hToken deposited local hToken addresses.
     *    @param _token deposited native / underlying Token addresses.
     *    @param _amount amounts of hTokens input.
     *    @param _deposit amount of deposited underlying / native tokens.
     *    @param _gasToBridgeOut gas allocated for omnichain execution.
     *
     */
    function _createDepositSingle(
        address _user,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        uint128 _gasToBridgeOut
    ) internal {
        //Deposit / Lock Tokens into Port
        IPort(localPortAddress).bridgeOut(_user, _hToken, _token, _amount, _deposit);

        //Deposit Gas to Port
        _depositGas(_gasToBridgeOut);

        // Cast to dynamic memory array
        address[] memory hTokens = new address[](1);
        hTokens[0] = _hToken;
        address[] memory tokens = new address[](1);
        tokens[0] = _token;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;
        uint256[] memory deposits = new uint256[](1);
        deposits[0] = _deposit;

        // Update State
        getDeposit[_getAndIncrementDepositNonce()] = Deposit({
            owner: _user,
            hTokens: hTokens,
            tokens: tokens,
            amounts: amounts,
            deposits: deposits,
            status: DepositStatus.Success,
            depositedGas: _gasToBridgeOut
        });
    }

    /**
     * @notice Function to create a pending deposit.
     *    @param _user user address.
     *    @param _hTokens deposited local hToken addresses.
     *    @param _tokens deposited native / underlying Token addresses.
     *    @param _amounts amounts of hTokens input.
     *    @param _deposits amount of deposited underlying / native tokens.
     *    @param _gasToBridgeOut gas allocated for omnichain execution.
     *
     */
    function _createDepositMultiple(
        address _user,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        uint128 _gasToBridgeOut
    ) internal {
        //Deposit / Lock Tokens into Port
        IPort(localPortAddress).bridgeOutMultiple(_user, _hTokens, _tokens, _amounts, _deposits);

        //Deposit Gas to Port
        _depositGas(_gasToBridgeOut);

        // Update State
        getDeposit[_getAndIncrementDepositNonce()] = Deposit({
            owner: _user,
            hTokens: _hTokens,
            tokens: _tokens,
            amounts: _amounts,
            deposits: _deposits,
            status: DepositStatus.Success,
            depositedGas: _gasToBridgeOut
        });
    }

    function _depositGas(uint128 _gasToBridgeOut) internal virtual {
        address(wrappedNativeToken).safeTransfer(localPortAddress, _gasToBridgeOut);
    }

    /**
     * @notice Function that returns Deposit nonce and increments counter.
     *
     */
    function _getAndIncrementDepositNonce() internal returns (uint32) {
        return depositNonce++;
    }

    /**
     * @dev External function to clear / refund a user's failed deposit.
     *    @param _depositNonce Identifier for user deposit.
     *
     */
    function _redeemDeposit(uint32 _depositNonce) internal {
        //Get Deposit
        Deposit storage deposit = getDeposit[_depositNonce];

        //Transfer token to depositor / user
        for (uint256 i = 0; i < deposit.hTokens.length;) {
            _clearToken(deposit.owner, deposit.hTokens[i], deposit.tokens[i], deposit.amounts[i], deposit.deposits[i]);

            unchecked {
                ++i;
            }
        }

        //Delete Failed Deposit Token Info
        delete getDeposit[_depositNonce];
    }

    /*///////////////////////////////////////////////////////////////
                REMOTE USER DEPOSIT INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to request balance clearance from a Port to a given user.
     *     @param _recipient token receiver.
     *     @param _hToken  local hToken addresse to clear balance for.
     *     @param _token  native / underlying token addresse to clear balance for.
     *     @param _amount amounts of hToken to clear balance for.
     *     @param _deposit amount of native / underlying tokens to clear balance for.
     *
     */
    function _clearToken(address _recipient, address _hToken, address _token, uint256 _amount, uint256 _deposit)
        internal
    {
        if (_amount - _deposit > 0) {
            IPort(localPortAddress).bridgeIn(_recipient, _hToken, _amount - _deposit);
        }

        if (_deposit > 0) {
            IPort(localPortAddress).withdraw(_recipient, _token, _deposit);
        }
    }

    /**
     * @notice Function to clear / refund a user's failed deposit. Called upon fallback in cross-chain messaging.
     *    @param _depositNonce Identifier for user deposit.
     *
     */
    function _clearDeposit(uint32 _depositNonce) internal {
        //Update and return Deposit
        getDeposit[_depositNonce].status = DepositStatus.Failed;
    }

    /*///////////////////////////////////////////////////////////////
                        ANYCALL INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function performs call to AnycallProxy Contract for cross-chain messaging.
     *   @param _calldata ABI encoded function call.
     */
    function _performCall(bytes memory _calldata) internal virtual {
        //Sends message to AnycallProxy
        IAnycallProxy(localAnyCallAddress).anyCall(
            rootBridgeAgentAddress, _calldata, rootChainId, AnycallFlags.FLAG_ALLOW_FALLBACK, ""
        );
    }

    /**
     * @notice Internal function repays gas used by Branch Bridge Agent to fulfill remote initiated interaction.
     *   @param _recipient address to send excess gas to.
     *   @param _initialGas gas used by Branch Bridge Agent.
     */
    function _payExecutionGas(address _recipient, uint256 _initialGas) internal virtual {
        //Gas remaining
        uint256 gasRemaining = wrappedNativeToken.balanceOf(address(this));

        //Unwrap Gas
        wrappedNativeToken.withdraw(gasRemaining);

        //Delete Remote Initiated Action State
        delete(remoteCallDepositedGas);

        ///Save gas left
        uint256 gasLeft = gasleft();

        //Get Branch Environment Execution Cost
        uint256 minExecCost = tx.gasprice * (MIN_EXECUTION_OVERHEAD + _initialGas - gasLeft);

        //Check if sufficient balance
        if (minExecCost > gasRemaining) {
            _forceRevert();
            return;
        }

        //Replenish Gas
        _replenishGas(minExecCost);

        //Transfer gas remaining to recipient
        SafeTransferLib.safeTransferETH(_recipient, gasRemaining - minExecCost);

        //Save Gas
        uint256 gasAfterTransfer = gasleft();

        //Check if sufficient balance
        if (gasLeft - gasAfterTransfer > TRANSFER_OVERHEAD) {
            _forceRevert();
            return;
        }
    }

    /**
     * @notice Internal function repays gas used by Branch Bridge Agent to fulfill remote initiated interaction.
     *   @param _depositNonce Identifier for user deposit attatched to interaction being fallback.
     *   @param _initialGas gas used by Branch Bridge Agent.
     */
    function _payFallbackGas(uint32 _depositNonce, uint256 _initialGas) internal virtual {
        //Save gas
        uint256 gasLeft = gasleft();

        //Get Branch Environment Execution Cost
        uint256 minExecCost = tx.gasprice * (MIN_FALLBACK_RESERVE + _initialGas - gasLeft);

        //Check if sufficient balance
        if (minExecCost > getDeposit[_depositNonce].depositedGas) {
            _forceRevert();
            return;
        }

        //Update user deposit reverts if not enough gas => user must boost deposit with gas
        getDeposit[_depositNonce].depositedGas -= minExecCost.toUint128();

        //Withdraw Gas
        IPort(localPortAddress).withdraw(address(this), address(wrappedNativeToken), minExecCost);

        //Unwrap Gas
        wrappedNativeToken.withdraw(minExecCost);

        //Replenish Gas
        _replenishGas(minExecCost);
    }

    /**
     * @notice Internal function that forces a revert.
     *   @param _executionGasSpent gas used by Branch Bridge Agent.
     */
    function _replenishGas(uint256 _executionGasSpent) internal virtual {
        //Deposit Gas
        IAnycallConfig(IAnycallProxy(localAnyCallAddress).config()).deposit{value: _executionGasSpent}(address(this));
    }

    /**
     * @notice Internal that clears gas allocated for usage with remote request
     */
    function _gasSwapIn(bytes memory gasData) internal virtual returns (uint256 gasAmount) {
        //Cast to uint256
        gasAmount = uint256(uint128(bytes16(gasData)));
        //Move Gas hTokens from Branch to Root / Mint Sufficient hTokens to match new port deposit
        IPort(localPortAddress).withdraw(address(this), address(wrappedNativeToken), gasAmount);
    }

    /**
     * @notice Internal function that returns 'from' address and 'fromChain' Id by performing an external call to AnycallExecutor Context.
     */
    function _getContext() internal view returns (address from, uint256 fromChainId) {
        (from, fromChainId,) = IAnycallExecutor(localAnyCallExecutorAddress).context();
    }

    /*///////////////////////////////////////////////////////////////
                        ANYCALL EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IApp
    function anyExecute(bytes calldata data)
        external
        virtual
        requiresExecutor
        returns (bool success, bytes memory result)
    {
        //Get Initial Gas Checkpoint
        uint256 initialGas = gasleft();

        //Save Length
        uint256 dataLength = data.length;

        //Save deposited gas
        uint128 depositedGas = _gasSwapIn(data[data.length - PARAMS_GAS_OUT:dataLength]).toUint128();

        //Store deposited gas for router interactions
        remoteCallDepositedGas = depositedGas;

        //Action Recipient
        address recipient = address(uint160(bytes20(data[PARAMS_START:PARAMS_START_SIGNED])));

        //Get Action Flag
        bytes1 flag = bytes1(data[0]);

        //DEPOSIT FLAG: 0 (No settlement)
        if (flag == 0x00) {
            //Get Settlement Nonce
            uint32 nonce = uint32(bytes4(data[PARAMS_START_SIGNED:25]));

            //Check if tx has already been executed
            if (executionHistory[nonce]) {
                _forceRevert();
                //Return true to avoid triggering anyFallback in case of `_forceRevert()` failure
                return (true, "already executed tx");
            }

            try BranchBridgeAgentExecutor(bridgeAgentExecutorAddress).executeNoSettlement(localRouterAddress, data)
            returns (bool, bytes memory res) {
                (success, result) = (true, res);
            } catch (bytes memory reason) {
                result = reason;
            }

            //Update tx state as executed
            executionHistory[nonce] = true;

            //DEPOSIT FLAG: 1 (Single Asset Settlement)
        } else if (flag == 0x01) {
            //Get Settlement Nonce
            uint32 nonce = uint32(bytes4(data[PARAMS_START_SIGNED:25]));

            //Check if tx has already been executed
            if (executionHistory[nonce]) {
                _forceRevert();
                //Return true to avoid triggering anyFallback in case of `_forceRevert()` failure
                return (true, "already executed tx");
            }

            //Try to execute remote request
            try BranchBridgeAgentExecutor(bridgeAgentExecutorAddress).executeWithSettlement(
                recipient, localRouterAddress, data
            ) returns (bool, bytes memory res) {
                (success, result) = (true, res);
            } catch (bytes memory reason) {
                result = reason;
            }

            //Update tx state as executed
            executionHistory[nonce] = true;

            //DEPOSIT FLAG: 2 (Multiple Settlement)
        } else if (flag == 0x02) {
            //Get deposit nonce
            uint32 nonce = uint32(bytes4(data[22:26]));

            //Check if tx has already been executed
            if (executionHistory[nonce]) {
                _forceRevert();
                //Return true to avoid triggering anyFallback in case of `_forceRevert()` failure
                return (true, "already executed tx");
            }

            //Try to execute remote request
            try BranchBridgeAgentExecutor(bridgeAgentExecutorAddress).executeWithSettlementMultiple(
                recipient, localRouterAddress, data
            ) returns (bool, bytes memory res) {
                (success, result) = (true, res);
            } catch (bytes memory reason) {
                result = reason;
            }

            //Update tx state as executed
            executionHistory[nonce] = true;

            //Unrecognized Function Selector
        } else {
            emit LogCallin(flag, data, rootChainId);
            //Deduct gas costs from deposit and replenish this bridge agent's execution budget.
            _payExecutionGas(recipient, initialGas);
            return (false, "unknown selector");
        }

        emit LogCallin(flag, data, rootChainId);

        //Deduct gas costs from deposit and replenish this bridge agent's execution budget.
        _payExecutionGas(recipient, initialGas);
    }

    /// @inheritdoc IApp
    function anyFallback(bytes calldata data)
        external
        virtual
        requiresExecutor
        returns (bool success, bytes memory result)
    {
        //Get Initial Gas Checkpoint
        uint256 initialGas = gasleft();

        //Save Flag
        bytes1 flag = data[0];

        //Save memory for Deposit Nonce
        uint32 _depositNonce;

        /// DEPOSIT FLAG: 0, 1, 2
        if ((flag == 0x00) || (flag == 0x01) || (flag == 0x02)) {
            //Check nonce calldata slice.
            _depositNonce = uint32(bytes4(data[PARAMS_START:PARAMS_TKN_START]));

            //Make tokens available to depositor.
            _clearDeposit(_depositNonce);

            emit LogCalloutFail(flag, data, rootChainId);

            //Deduct gas costs from deposit and replenish this bridge agent's execution budget.
            _payFallbackGas(_depositNonce, initialGas);

            return (true, "");

            /// DEPOSIT FLAG: 3
        } else if (flag == 0x03) {
            _depositNonce = uint32(bytes4(data[PARAMS_START + PARAMS_START:PARAMS_TKN_START + PARAMS_START]));

            //Make tokens available to depositor.
            _clearDeposit(_depositNonce);

            emit LogCalloutFail(flag, data, rootChainId);

            //Deduct gas costs from deposit and replenish this bridge agent's execution budget.
            _payFallbackGas(_depositNonce, initialGas);

            return (true, "");

            /// DEPOSIT FLAG: 4, 5
        } else if ((flag == 0x04) || (flag == 0x05)) {
            //Save nonce
            _depositNonce = uint32(bytes4(data[PARAMS_START_SIGNED:PARAMS_START_SIGNED + PARAMS_TKN_START]));

            //Make tokens available to depositor.
            _clearDeposit(_depositNonce);

            emit LogCalloutFail(flag, data, rootChainId);

            //Deduct gas costs from deposit and replenish this bridge agent's execution budget.
            _payFallbackGas(_depositNonce, initialGas);

            return (true, "");

            /// DEPOSIT FLAG: 6
        } else if (flag == 0x06) {
            //Save nonce
            _depositNonce = uint32(
                bytes4(data[PARAMS_START_SIGNED + PARAMS_START:PARAMS_START_SIGNED + PARAMS_TKN_START + PARAMS_START])
            );

            //Make tokens available to depositor.
            _clearDeposit(_depositNonce);

            emit LogCalloutFail(flag, data, rootChainId);

            //Deduct gas costs from deposit and replenish this bridge agent's execution budget.
            _payFallbackGas(_depositNonce, initialGas);

            return (true, "");

            //Unrecognized Function Selector
        } else {
            return (false, "unknown selector");
        }
    }

    /// @inheritdoc IBranchBridgeAgent
    function depositGasAnycallConfig() external payable {
        _replenishGas(msg.value);
    }

    /// @inheritdoc IBranchBridgeAgent
    function forceRevert() external requiresAgentExecutor {
        _forceRevert();
    }

    /**
     * @notice Reverts the current transaction with a "no enough budget" message.
     * @dev This function is used to revert the current transaction with a "no enough budget" message.
     */
    function _forceRevert() internal virtual {
        IAnycallConfig anycallConfig = IAnycallConfig(IAnycallProxy(localAnyCallAddress).config());
        uint256 executionBudget = anycallConfig.executionBudget(address(this));

        // Withdraw all execution gas budget from anycall for tx to revert with "no enough budget"
        if (executionBudget > 0) try anycallConfig.withdraw(executionBudget) {} catch {}
    }

    /*///////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function that normalizes an input to 18 decimal places.
     * @param _amount amount of tokens
     * @param _decimals number of decimal places
     */
    function _normalizeDecimals(uint256 _amount, uint8 _decimals) internal pure returns (uint256) {
        return _decimals == 18 ? _amount : _amount * (10 ** _decimals) / 1 ether;
    }

    /**
     * @notice Internal function to normalize decimals of multiple tokens.
     * @param _deposits Array of deposit amounts.
     * @param _tokens Array of token addresses.
     */
    function _normalizeDecimalsMultiple(uint256[] memory _deposits, address[] memory _tokens)
        internal
        view
        returns (uint256[] memory deposits)
    {
        for (uint256 i = 0; i < _deposits.length; i++) {
            deposits[i] = _normalizeDecimals(_deposits[i], ERC20(_tokens[i]).decimals());
        }
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

    /// @notice Modifier that verifies caller is the Bridge Agent Executor.
    modifier requiresAgentExecutor() {
        if (msg.sender != bridgeAgentExecutorAddress) revert UnrecognizedBridgeAgentExecutor();
        _;
    }

    /// @notice Modifier verifies the caller is the Anycall Executor. 
    modifier requiresExecutor() {
        _requiresExecutor();
        _;
    }

    /// @notice Verifies the caller is the Anycall Executor. Internal function used in modifier to reduce contract bytesize.
    function _requiresExecutor() internal view virtual {
        if (msg.sender != localAnyCallExecutorAddress) revert AnycallUnauthorizedCaller();
        (address from,,) = IAnycallExecutor(localAnyCallExecutorAddress).context();
        if (from != rootBridgeAgentAddress) revert AnycallUnauthorizedCaller();
    }

    /// @notice Modifier that verifies caller is Branch Bridge Agent's Router.
    modifier requiresRouter() {
        _requiresRouter();
        _;
    }

    /// @notice Internal function that verifies caller is Branch Bridge Agent's Router. Reuse to reduce contract bytesize.
    function _requiresRouter() internal view {
        if (msg.sender != localRouterAddress) revert UnrecognizedCallerNotRouter();
    }

    /// @notice Modifier that verifies enough gas is deposited to pay for an eventual fallback call.
    modifier requiresFallbackGas() {
        _requiresFallbackGas();
        _;
    }

    /// @notice Verifies enough gas is deposited to pay for an eventual fallback call. Reuse to reduce contract bytesize.
    function _requiresFallbackGas() internal view virtual {
        if (msg.value <= MIN_FALLBACK_RESERVE * tx.gasprice) revert InsufficientGas();
    }

    /// @notice Verifies enough gas is deposited to pay for an eventual fallback call.
    function _requiresFallbackGas(uint256 _depositedGas) internal view virtual {
        if (_depositedGas <= MIN_FALLBACK_RESERVE * tx.gasprice) revert InsufficientGas();
    }

    fallback() external payable {}
}
