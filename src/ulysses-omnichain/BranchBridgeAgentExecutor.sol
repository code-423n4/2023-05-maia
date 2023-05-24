// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {IBranchRouter as IRouter} from "./interfaces/IBranchRouter.sol";

import {BranchBridgeAgent} from "./BranchBridgeAgent.sol";
import {SettlementParams, SettlementMultipleParams} from "./interfaces/IBranchBridgeAgent.sol";

/// @title Library for Branch Bridge Agent Executor Deployment
library DeployBranchBridgeAgentExecutor {
    function deploy() external returns (address) {
        return address(new BranchBridgeAgentExecutor());
    }
}

/**
 * @title  Branch Bridge Agent Executor Contract
 * @notice This contract is used for requesting token deposit clearance and
 *         executing transactions in response to requests from the root environment.
 * @dev    Execution is "sandboxed" meaning upon tx failure both token deposits
 *         and interactions with external contracts should be reverted and caught.
 */
contract BranchBridgeAgentExecutor is Ownable {
    /*///////////////////////////////////////////////////////////////
                            ENCODING CONSTS
    //////////////////////////////////////////////////////////////*/

    /// AnyExec Decode Consts

    uint8 internal constant PARAMS_START = 1;

    uint8 internal constant PARAMS_START_SIGNED = 21;

    uint8 internal constant PARAMS_END_SIGNED_OFFSET = 26;

    uint8 internal constant PARAMS_ENTRY_SIZE = 32;

    uint8 internal constant PARAMS_ADDRESS_SIZE = 20;

    uint8 internal constant PARAMS_TKN_SET_SIZE = 128;

    uint8 internal constant PARAMS_GAS_OUT = 16;

    /// ClearTokens Decode Consts

    uint8 internal constant PARAMS_TKN_START = 5;

    uint8 internal constant PARAMS_AMT_OFFSET = 64;

    uint8 internal constant PARAMS_DEPOSIT_OFFSET = 96;

    constructor() {
        _initializeOwner(msg.sender);
    }

    /*///////////////////////////////////////////////////////////////
                        EXECUTOR EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to execute a crosschain request without any settlement.
     * @param _router Address of the router contract to execute the request.
     * @param _data Data received from messaging layer.
     * @return success Boolean indicating if the operation was successful.
     * @return result Result of the execution.
     * @dev SETTLEMENT FLAG: 0 (No settlement)
     */
    function executeNoSettlement(address _router, bytes calldata _data)
        external
        onlyOwner
        returns (bool success, bytes memory result)
    {
        //Execute remote request
        (success, result) = IRouter(_router).anyExecuteNoSettlement(_data[25:_data.length - PARAMS_GAS_OUT]);
    }

    /**
     * @notice Function to execute a crosschain request with a single settlement.
     * @param _recipient Address of the recipient of the settlement.
     * @param _router Address of the router contract to execute the request.
     * @param _data Data received from messaging layer.
     * @return success Boolean indicating if the operation was successful.
     * @return result Result of the execution.
     * @dev SETTLEMENT FLAG: 1 (Single Settlement)
     */
    function executeWithSettlement(address _recipient, address _router, bytes calldata _data)
        external
        onlyOwner
        returns (bool success, bytes memory result)
    {
        //Clear Token / Execute Settlement
        SettlementParams memory sParams = SettlementParams({
            settlementNonce: uint32(bytes4(_data[PARAMS_START_SIGNED:25])),
            recipient: _recipient,
            hToken: address(uint160(bytes20(_data[25:45]))),
            token: address(uint160(bytes20(_data[45:65]))),
            amount: uint256(bytes32(_data[65:97])),
            deposit: uint256(bytes32(_data[97:129]))
        });

        //Bridge In Assets
        BranchBridgeAgent(payable(msg.sender)).clearToken(
            sParams.recipient, sParams.hToken, sParams.token, sParams.amount, sParams.deposit
        );

        if (_data.length - PARAMS_GAS_OUT > 129) {
            //Execute remote request
            (success, result) = IRouter(_router).anyExecuteSettlement(_data[129:_data.length - PARAMS_GAS_OUT], sParams);
        } else {
            success = true;
        }
    }

    /**
     * @notice Function to execute a crosschain request with multiple settlements.
     * @param _recipient Address of the recipient of the settlement.
     * @param _router Address of the router contract to execute the request.
     * @param _data Data received from messaging layer.
     * @return success Boolean indicating if the operation was successful.
     * @return result Result of the execution.
     * @dev SETTLEMENT FLAG: 2 (Multiple Settlements)
     */
    function executeWithSettlementMultiple(address _recipient, address _router, bytes calldata _data)
        external
        onlyOwner
        returns (bool success, bytes memory result)
    {
        //Bridge In Assets and Save Deposit Params
        SettlementMultipleParams memory sParams = BranchBridgeAgent(payable(msg.sender)).clearTokens(
            _data[
                PARAMS_START_SIGNED:
                    PARAMS_START_SIGNED + PARAMS_TKN_START
                        + (uint8(bytes1(_data[PARAMS_START_SIGNED])) * uint16(PARAMS_TKN_SET_SIZE))
            ],
            _recipient
        );

        // Execute Calldata if any
        if (
            _data.length - PARAMS_GAS_OUT
                > PARAMS_START_SIGNED + PARAMS_TKN_START
                    + (uint8(bytes1(_data[PARAMS_START_SIGNED])) * uint16(PARAMS_TKN_SET_SIZE))
        ) {
            //Try to execute remote request
            (success, result) = IRouter(_router).anyExecuteSettlementMultiple(
                _data[
                    PARAMS_END_SIGNED_OFFSET + (uint8(bytes1(_data[PARAMS_START_SIGNED])) * PARAMS_TKN_SET_SIZE):
                        _data.length - PARAMS_GAS_OUT
                ],
                sParams
            );
        } else {
            success = true;
        }
    }
}
