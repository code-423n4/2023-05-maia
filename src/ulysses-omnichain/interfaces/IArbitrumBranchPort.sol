// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IBranchPort} from "./IBranchPort.sol";

/**
 * @title  Arbitrum Branch Port Contract
 * @author MaiaDAO
 * @notice Ulyses `Port` implementation for Arbitrum Branch Chain deployment.
 *         This contract is used to manage the deposit and withdrawal of underlying assets
 *         from the Arbitrum Branch Chain in response to Branch Bridge Agents' requests.
 *         Manages Bridge Agents and their factories as well as the chain's strategies and
 *         their tokens.
 */
interface IArbitrumBranchPort is IBranchPort {
    /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to deposit underlying / native token amount into Port in exchange for Local hToken.
     *     @param _depositor underlying / native token depositor.
     *     @param _recipient hToken receiver.
     *     @param _underlyingAddress underlying / native token address.
     *     @param _amount amount of tokens.
     */
    function depositToPort(address _depositor, address _recipient, address _underlyingAddress, uint256 _amount)
        external;

    /**
     * @notice Function to withdraw underlying / native token amount into Port in exchange for Local hToken.
     *     @param _depositor underlying / native token depositor.
     *     @param _recipient hToken receiver.
     *     @param _globalAddress global hToken address.
     *     @param _amount amount of tokens.
     */
    function withdrawFromPort(address _depositor, address _recipient, address _globalAddress, uint256 _amount)
        external;

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error UnknownToken();
    error UnknownUnderlyingToken();
}
