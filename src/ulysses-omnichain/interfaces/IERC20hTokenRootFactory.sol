// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20hTokenRoot} from "../token/ERC20hTokenRoot.sol";

/**
 * @title ERC20 hToken Contract for deployment of new hTokens in Root Chain of Hermes Omnichain Incentives System.
 * @author MaiaDAO
 * @dev This contract is used to deploy new hTokens in the Root Chain of the Hermes Omnichain Incentives System.
 */
interface IERC20hTokenRootFactory {
    /*///////////////////////////////////////////////////////////////
                            hTOKEN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Function to create a new hToken.
     * @param _name Name of the Token.
     * @param _symbol Symbol of the Token.
     */
    function createToken(string memory _name, string memory _symbol) external returns (ERC20hTokenRoot newToken);

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error UnrecognizedCoreRouter();
}
