// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title `ERC20hTokenBranch`
 * @author MaiaDAO.
 * @notice ERC20 hToken contract deployed in the Branch Chains of the Hermes Omnichain Liquidity System.
 *         Represents a token deposited in the BranchPort.
 */
interface IERC20hTokenBranch {
    /*///////////////////////////////////////////////////////////////
                        ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to mint tokens in the Branch Chain.
     * @param account Address of the account to receive the tokens.
     * @param amount Amount of tokens to be minted.
     * @return Boolean indicating if the operation was successful.
     */
    function mint(address account, uint256 amount) external returns (bool);

    /**
     * @notice Function to burn tokens in the Branch Chain.
     * @param value Amount of tokens to be burned.
     */
    function burn(uint256 value) external;
}
