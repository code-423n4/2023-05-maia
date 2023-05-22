// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20hTokenBranch} from "../token/ERC20hTokenBranch.sol";

/**
 * @title ERC20hTokenBranchFactory Interface
 * @author MaiaDAO
 * @dev  Factory Interface for deployment of new ERC20hTokenBranch in Branch Chains of Ulysses Omnichain Liquidity Protocol.
 */
interface IERC20hTokenBranchFactory {
    /*///////////////////////////////////////////////////////////////
                            hTOKEN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Function to create a new Branch hToken.
     * @param _name Name of the Token.
     * @param _symbol Symbol of the Token.
     */
    function createToken(string memory _name, string memory _symbol) external returns (ERC20hTokenBranch newToken);

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error UnrecognizedCoreRouter();

    error UnrecognizedPort();
}
