// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {IRootRouter as IRouter} from "./interfaces/IRootRouter.sol";
import {IRootBridgeAgent} from "./interfaces/IRootBridgeAgent.sol";

import {DepositParams, DepositMultipleParams} from "./interfaces/IRootBridgeAgent.sol";
import {RootBridgeAgent} from "./RootBridgeAgent.sol";

/// @title Library for Root Bridge Agent Executor Deployment
library DeployRootBridgeAgentExecutor {
    function deploy(address _owner) external returns (address) {
        return address(new RootBridgeAgentExecutor(_owner));
    }
}

/**
 * @title  Root Bridge Agent Executor Contract
 * @notice This contract is used for requesting token settlement clearance and
 *         executing transaction requests from the branch chains.
 * @dev    Execution is "sandboxed" meaning upon tx failure both token settlements
 *         and interactions with external contracts should be reverted and caught.
 */
contract RootBridgeAgentExecutor is Ownable {
    /*///////////////////////////////////////////////////////////////
                            ENCODING CONSTS
    //////////////////////////////////////////////////////////////*/

    /// Remote Execution Consts

    uint8 internal constant PARAMS_START = 1;

    uint8 internal constant PARAMS_START_SIGNED = 21;

    uint8 internal constant PARAMS_END_OFFSET = 9;

    uint8 internal constant PARAMS_END_SIGNED_OFFSET = 29;

    uint8 internal constant PARAMS_ENTRY_SIZE = 32;

    uint8 internal constant PARAMS_ADDRESS_SIZE = 20;

    uint8 internal constant PARAMS_TKN_SET_SIZE = 104;

    uint8 internal constant PARAMS_TKN_SET_SIZE_MULTIPLE = 128;

    uint8 internal constant PARAMS_GAS_IN = 32;

    uint8 internal constant PARAMS_GAS_OUT = 16;

    /// BridgeIn Consts

    uint8 internal constant PARAMS_TKN_START = 5;

    uint8 internal constant PARAMS_AMT_OFFSET = 64;

    uint8 internal constant PARAMS_DEPOSIT_OFFSET = 96;

    constructor(address owner) {
        _initializeOwner(owner);
    }

    /*///////////////////////////////////////////////////////////////
                        EXECUTOR EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Execute a system request from a remote chain
     * @param _router The router contract address
     * @param _data The encoded request data
     * @param _fromChainId The chain id of the chain that sent the request
     * @return success Whether the request was successful
     * @return result The result of the request
     * @dev DEPOSIT FLAG: 0 (System request / response)
     */
    function executeSystemRequest(address _router, bytes calldata _data, uint24 _fromChainId)
        external
        onlyOwner
        returns (bool success, bytes memory result)
    {
        //Try to execute remote request
        (success, result) = IRouter(_router).anyExecuteResponse(
            bytes1(_data[PARAMS_TKN_START]), _data[6:_data.length - PARAMS_GAS_IN], _fromChainId
        );
    }

    /**
     * @notice Execute a remote request from a remote chain
     * @param _router The router contract address
     * @param _data The encoded request data
     * @param _fromChainId The chain id of the chain that sent the request
     * @return success Whether the request was successful
     * @return result The result of the request
     * @dev DEPOSIT FLAG: 1 (Call without Deposit)
     */
    function executeNoDeposit(address _router, bytes calldata _data, uint24 _fromChainId)
        external
        onlyOwner
        returns (bool success, bytes memory result)
    {
        //Execute remote request
        (success, result) =
            IRouter(_router).anyExecute(bytes1(_data[5]), _data[6:_data.length - PARAMS_GAS_IN], _fromChainId);
    }

    /**
     * @notice Execute a remote request from a remote chain
     * @param _router The router contract address
     * @param _data The encoded request data
     * @param _fromChainId The chain id of the chain that sent the request
     * @return success Whether the request was successful
     * @return result The result of the request
     * @dev DEPOSIT FLAG: 2 (Call with Deposit)
     */
    function executeWithDeposit(address _router, bytes calldata _data, uint24 _fromChainId)
        external
        onlyOwner
        returns (bool success, bytes memory result)
    {
        //Read Deposit Params
        DepositParams memory dParams = DepositParams({
            depositNonce: uint32(bytes4(_data[PARAMS_START:PARAMS_TKN_START])),
            hToken: address(uint160(bytes20(_data[PARAMS_TKN_START:25]))),
            token: address(uint160(bytes20(_data[25:45]))),
            amount: uint256(bytes32(_data[45:77])),
            deposit: uint256(bytes32(_data[77:109])),
            toChain: uint24(bytes3(_data[109:112]))
        });

        //Bridge In Assets
        _bridgeIn(_router, dParams, _fromChainId);

        if (_data.length - PARAMS_GAS_IN > 112) {
            //Execute remote request
            (success, result) = IRouter(_router).anyExecuteDepositSingle(
                _data[112], _data[113:_data.length - PARAMS_GAS_IN], dParams, _fromChainId
            );
        } else {
            success = true;
        }
    }

    /**
     * @notice Execute a remote request from a remote chain
     * @param _router The router contract address
     * @param _data The encoded request data
     * @param _fromChainId The chain id of the chain that sent the request
     * @return success Whether the request was successful
     * @return result The result of the request
     * @dev DEPOSIT FLAG: 3 (Call with multiple asset Deposit)
     */
    function executeWithDepositMultiple(address _router, bytes calldata _data, uint24 _fromChainId)
        external
        onlyOwner
        returns (bool success, bytes memory result)
    {
        //Bridge In Assets and Save Deposit Params
        DepositMultipleParams memory dParams = _bridgeInMultiple(
            _router,
            _data[
                PARAMS_START:
                    PARAMS_END_OFFSET + uint16(uint8(bytes1(_data[PARAMS_START]))) * PARAMS_TKN_SET_SIZE_MULTIPLE
            ],
            _fromChainId
        );

        uint8 numOfAssets = uint8(bytes1(_data[PARAMS_START]));
        uint256 length = _data.length;

        if (
            length - PARAMS_GAS_IN
                > PARAMS_END_OFFSET + uint16(uint8(bytes1(_data[PARAMS_START]))) * PARAMS_TKN_SET_SIZE_MULTIPLE
        ) {
            //Try to execute remote request
            (success, result) = IRouter(_router).anyExecuteDepositMultiple(
                bytes1(_data[PARAMS_END_OFFSET + uint16(numOfAssets) * PARAMS_TKN_SET_SIZE_MULTIPLE]),
                _data[
                    PARAMS_START + PARAMS_END_OFFSET + uint16(numOfAssets) * PARAMS_TKN_SET_SIZE_MULTIPLE:
                        length - PARAMS_GAS_IN
                ],
                dParams,
                _fromChainId
            );
        } else {
            success = true;
        }
    }

    /**
     * @notice Execute a remote request from a remote chain
     * @param _account The account that will execute the request
     * @param _router The router contract address
     * @param _data The encoded request data
     * @param _fromChainId The chain id of the chain that sent the request
     * @return success Whether the request was successful
     * @return result The result of the request
     * @dev DEPOSIT FLAG: 4 (Call without Deposit + msg.sender)
     */
    function executeSignedNoDeposit(address _account, address _router, bytes calldata _data, uint24 _fromChainId)
        external
        onlyOwner
        returns (bool success, bytes memory result)
    {
        //Execute remote request
        (success, result) =
            IRouter(_router).anyExecuteSigned(_data[25], _data[26:_data.length - PARAMS_GAS_IN], _account, _fromChainId);
    }

    /**
     * @notice Execute a remote request from a remote chain with single asset deposit
     * @param _account The account that will execute the request
     * @param _router The router contract address
     * @param _data The encoded request data
     * @param _fromChainId The chain id of the chain that sent the request
     * @return success Whether the request was successful
     * @return result The result of the request
     * @dev DEPOSIT FLAG: 5 (Call with Deposit + msg.sender)
     */
    function executeSignedWithDeposit(address _account, address _router, bytes calldata _data, uint24 _fromChainId)
        external
        onlyOwner
        returns (bool success, bytes memory result)
    {
        //Read Deposit Params
        DepositParams memory dParams = DepositParams({
            depositNonce: uint32(bytes4(_data[PARAMS_START_SIGNED:25])),
            hToken: address(uint160(bytes20(_data[25:45]))),
            token: address(uint160(bytes20(_data[45:65]))),
            amount: uint256(bytes32(_data[65:97])),
            deposit: uint256(bytes32(_data[97:129])),
            toChain: uint24(bytes3(_data[129:132]))
        });

        //Bridge In Asset
        _bridgeIn(_account, dParams, _fromChainId);

        if (_data.length - PARAMS_GAS_IN > 132) {
            //Execute remote request
            (success, result) = IRouter(_router).anyExecuteSignedDepositSingle(
                _data[132], _data[133:_data.length - PARAMS_GAS_IN], dParams, _account, _fromChainId
            );
        } else {
            success = true;
        }
    }

    /**
     * @notice Execute a remote request from a remote chain with multiple asset deposit
     * @param _account The account that will execute the request
     * @param _router The router contract address
     * @param _data The encoded request data
     * @param _fromChainId The chain id of the chain that sent the request
     * @return success Whether the request was successful
     * @return result The result of the request
     * @dev DEPOSIT FLAG: 6 (Call with multiple asset Deposit + msg.sender)
     */
    function executeSignedWithDepositMultiple(
        address _account,
        address _router,
        bytes calldata _data,
        uint24 _fromChainId
    ) external onlyOwner returns (bool success, bytes memory result) {
        //Bridge In Assets
        DepositMultipleParams memory dParams = _bridgeInMultiple(
            _account,
            _data[
                PARAMS_START_SIGNED:
                    PARAMS_END_SIGNED_OFFSET
                        + uint16(uint8(bytes1(_data[PARAMS_START_SIGNED]))) * PARAMS_TKN_SET_SIZE_MULTIPLE
            ],
            _fromChainId
        );

        {
            if (
                _data.length - PARAMS_GAS_IN
                    > PARAMS_END_SIGNED_OFFSET
                        + uint16(uint8(bytes1(_data[PARAMS_START_SIGNED]))) * PARAMS_TKN_SET_SIZE_MULTIPLE
            ) {
                //Execute remote request
                (success, result) = IRouter(_router).anyExecuteSignedDepositMultiple(
                    _data[PARAMS_END_SIGNED_OFFSET
                        + uint16(uint8(bytes1(_data[PARAMS_START_SIGNED]))) * PARAMS_TKN_SET_SIZE_MULTIPLE],
                    _data[
                        PARAMS_START + PARAMS_END_SIGNED_OFFSET
                            + uint16(uint8(bytes1(_data[PARAMS_START_SIGNED]))) * PARAMS_TKN_SET_SIZE_MULTIPLE:
                            _data.length - PARAMS_GAS_IN
                    ],
                    dParams,
                    _account,
                    _fromChainId
                );
            } else {
                success = true;
            }
        }
    }

    /**
     * @notice Retry a settlement request that has not yet been executed in destination chain.
     * @param _settlementNonce The settlement nonce of the request to retry.
     * @return success Whether the request was successful
     * @return result The result of the request
     * @dev DEPOSIT FLAG: 7 (Retry Settlement)
     */
    function executeRetrySettlement(uint32 _settlementNonce)
        external
        onlyOwner
        returns (bool success, bytes memory result)
    {
        //Execute remote request
        RootBridgeAgent(payable(msg.sender)).retrySettlement(_settlementNonce, 0);
        //Trigger retry success (no guarantees about settlement success at this point)
        (success, result) = (true, "");
    }

    /**
     * @notice Internal function to move assets from branch chain to root omnichain environment.
     *   @param _dParams Cross-Chain Deposit of Multiple Tokens Params.
     *   @param _fromChain chain to bridge from.
     *
     */
    function _bridgeIn(address _recipient, DepositParams memory _dParams, uint24 _fromChain) internal {
        //Request assets for decoded request.
        RootBridgeAgent(payable(msg.sender)).bridgeIn(_recipient, _dParams, _fromChain);
    }

    /**
     * @notice Internal function to move assets from branch chain to root omnichain environment.
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
    function _bridgeInMultiple(address _recipient, bytes calldata _dParams, uint24 _fromChain)
        internal
        returns (DepositMultipleParams memory dParams)
    {
        // Parse Parameters
        uint8 numOfAssets = uint8(bytes1(_dParams[0]));
        uint32 nonce = uint32(bytes4(_dParams[PARAMS_START:5]));
        uint24 toChain = uint24(bytes3(_dParams[_dParams.length - 3:_dParams.length]));

        address[] memory hTokens = new address[](numOfAssets);
        address[] memory tokens = new address[](numOfAssets);
        uint256[] memory amounts = new uint256[](numOfAssets);
        uint256[] memory deposits = new uint256[](numOfAssets);

        for (uint256 i = 0; i < uint256(uint8(numOfAssets));) {
            //Parse Params
            hTokens[i] = address(
                uint160(
                    bytes20(
                        bytes32(
                            _dParams[
                                PARAMS_TKN_START + (PARAMS_ENTRY_SIZE * i) + 12:
                                    PARAMS_TKN_START + (PARAMS_ENTRY_SIZE * (PARAMS_START + i))
                            ]
                        )
                    )
                )
            );

            tokens[i] = address(
                uint160(
                    bytes20(
                        _dParams[
                            PARAMS_TKN_START + PARAMS_ENTRY_SIZE * uint16(i + numOfAssets) + 12:
                                PARAMS_TKN_START + PARAMS_ENTRY_SIZE * uint16(PARAMS_START + i + numOfAssets)
                        ]
                    )
                )
            );

            amounts[i] = uint256(
                bytes32(
                    _dParams[
                        PARAMS_TKN_START + PARAMS_AMT_OFFSET * uint16(numOfAssets) + (PARAMS_ENTRY_SIZE * uint16(i)):
                            PARAMS_TKN_START + PARAMS_AMT_OFFSET * uint16(numOfAssets)
                                + PARAMS_ENTRY_SIZE * uint16(PARAMS_START + i)
                    ]
                )
            );

            deposits[i] = uint256(
                bytes32(
                    _dParams[
                        PARAMS_TKN_START + PARAMS_DEPOSIT_OFFSET * uint16(numOfAssets) + (PARAMS_ENTRY_SIZE * uint16(i)):
                            PARAMS_TKN_START + PARAMS_DEPOSIT_OFFSET * uint16(numOfAssets)
                                + PARAMS_ENTRY_SIZE * uint16(PARAMS_START + i)
                    ]
                )
            );

            unchecked {
                ++i;
            }
        }

        //Save Deposit Multiple Params
        dParams = DepositMultipleParams({
            numberOfAssets: numOfAssets,
            depositNonce: nonce,
            hTokens: hTokens,
            tokens: tokens,
            amounts: amounts,
            deposits: deposits,
            toChain: toChain
        });

        RootBridgeAgent(payable(msg.sender)).bridgeInMultiple(_recipient, dParams, _fromChain);
    }
}
