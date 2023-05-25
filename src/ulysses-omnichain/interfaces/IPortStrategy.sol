// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title  Base PortStrategy Contract
 * @author MaiaDAO
 * @notice Base Contract for interfacing with Brach Port Strategy contracts
 *         whitelisted by the chain's Branch Port to manage a limited amount
 *         of one or more Strategy Tokens.
 */
interface IPortStrategy {
    /*///////////////////////////////////////////////////////////////
                          TOKEN MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to withdraw underlying / native token amount back into Branch Port.
     *   @param _recipient hToken receiver.
     *   @param _token native token address.
     *   @param _amount amount of tokens.
     */
    function withdraw(address _recipient, address _token, uint256 _amount) external;

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error UnrecognizedPort();
}
