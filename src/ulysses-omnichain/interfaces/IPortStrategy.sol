// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/**
 * @title IPortStrategy Interface.
 * @author MaiaDAO.
 * @notice Interface for Brach Port Strategy contracts.
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
