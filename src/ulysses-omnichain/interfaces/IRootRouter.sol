// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {WETH9} from "../interfaces/IWETH9.sol";

import {IRootPort as IPort} from "../interfaces/IRootPort.sol";
import {DepositParams, DepositMultipleParams} from "../interfaces/IRootBridgeAgent.sol";

/**
 * @title `RootRouter`
 * @author MaiaDAO
 * @notice Contract Interface for Root Router contracts in charge of interacting with Root Bridge Agents.
 *         This contract for deployment in Branch Chains of the Ulysses Omnichain System.
 */
interface IRootRouter {
    /*///////////////////////////////////////////////////////////////
                        ANYCALL FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     *     @notice Function responsible of executing a branch router response.
     *     @param funcId 1 byte called Router function identifier.
     *     @param encodedData data received from messaging layer.
     *     @param fromChainId chain where the request originated from.
     *
     */
    function anyExecuteResponse(bytes1 funcId, bytes memory encodedData, uint24 fromChainId)
        external
        payable
        returns (bool success, bytes memory result);

    /**
     *     @notice Function responsible of executing a crosschain request without any deposit.
     *     @param funcId 1 byte Router function identifier.
     *     @param encodedData data received from messaging layer.
     *     @param fromChainId chain where the request originated from.
     *
     */
    function anyExecute(bytes1 funcId, bytes memory encodedData, uint24 fromChainId)
        external
        payable
        returns (bool success, bytes memory result);

    /**
     *   @notice Function responsible of executing a crosschain request which contains cross-chain deposit information attached.
     *   @param funcId 1 byte Router function identifier.
     *   @param encodedData execution data received from messaging layer.
     *   @param dParams cross-chain deposit information.
     *   @param fromChainId chain where the request originated from.
     *
     */
    function anyExecuteDepositSingle(
        bytes1 funcId,
        bytes memory encodedData,
        DepositParams memory dParams,
        uint24 fromChainId
    ) external payable returns (bool success, bytes memory result);

    /**
     *   @notice Function responsible of executing a crosschain request which contains cross-chain deposit information for multiple assets attached.
     *   @param funcId 1 byte Router function identifier.
     *   @param encodedData execution data received from messaging layer.
     *   @param dParams cross-chain multiple deposit information.
     *   @param fromChainId chain where the request originated from.
     *
     */
    function anyExecuteDepositMultiple(
        bytes1 funcId,
        bytes memory encodedData,
        DepositMultipleParams memory dParams,
        uint24 fromChainId
    ) external payable returns (bool success, bytes memory result);

    /**
     * @notice Reverts when called
     * @param funcId 1 byte Router function identifier.
     * @param encodedData execution data received from messaging layer.
     * @param userAccount user account address.
     * @param fromChainId chain where the request originated from.
     */
    function anyExecuteSigned(bytes1 funcId, bytes memory encodedData, address userAccount, uint24 fromChainId)
        external
        payable
        returns (bool success, bytes memory result);

    /**
     * @notice Reverts when called
     * @param funcId 1 byte Router function identifier.
     * @param encodedData execution data received from messaging layer.
     * @param dParams cross-chain deposit information.
     * @param userAccount user account address.
     * @param fromChainId chain where the request originated from.
     */
    function anyExecuteSignedDepositSingle(
        bytes1 funcId,
        bytes memory encodedData,
        DepositParams memory dParams,
        address userAccount,
        uint24 fromChainId
    ) external payable returns (bool success, bytes memory result);

    /**
     * @notice Reverts when called
     * @param funcId 1 byte Router function identifier.
     * @param encodedData execution data received from messaging layer.
     * @param dParams cross-chain multiple deposit information.
     * @param userAccount user account address.
     * @param fromChainId chain where the request originated from.
     */
    function anyExecuteSignedDepositMultiple(
        bytes1 funcId,
        bytes memory encodedData,
        DepositMultipleParams memory dParams,
        address userAccount,
        uint24 fromChainId
    ) external payable returns (bool success, bytes memory result);

    /*///////////////////////////////////////////////////////////////
                             ERRORS
    //////////////////////////////////////////////////////////////*/

    error UnrecognizedBridgeAgentExecutor();
}
