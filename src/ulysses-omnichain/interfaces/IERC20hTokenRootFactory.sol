// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20hTokenRoot} from "../token/ERC20hTokenRoot.sol";

/**
 * @title  Factory Contract for Root hTokens
 * @author MaiaDAO
 * @notice Factory contract allowing for permissionless deployment of new Root hTokens in the
 *  	   Root Chain of Ulysses Omnichain Liquidity Protocol.
 * @dev    This contract is called by the chain's Core Root Router.
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
