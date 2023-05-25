// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title  ERC20 hToken Root Contract
 * @author MaiaDAO.
 * @notice ERC20 hToken contract deployed in the Root Chain of the Ulysses Omnichain Liquidity System.
 *         1:1 ERC20 representation of a token deposited in a Branch Chain's Port.
 * @dev    This asset is minted / burned in reflection of it's origin Branch Port balance. Should not
 *         be burned being stored in Root Port instead if Branch hToken mint is requested.
 */
interface IERC20hTokenRoot {
    /*///////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice View Function returns Local Network Identifier.
    function localChainId() external view returns (uint256);

    /// @notice View Function returns Root Port Address.
    function rootPortAddress() external view returns (address);

    /// @notice View Function returns Local Branch Port Address.
    function localBranchPortAddress() external view returns (address);

    /// @notice View Function returns the address of the Factory that deployed this token.
    function factoryAddress() external view returns (address);

    /**
     * @notice View Function returns Token's balance in a given Branch Chain's Port.
     *   @param chainId Identifier of the Branch Chain.
     *   @return Token's balance in the given Branch Chain's Port.
     */
    function getTokenBalance(uint256 chainId) external view returns (uint256);

    /*///////////////////////////////////////////////////////////////
                        ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to mint hTokens in the Root Chain to match Branch Chain deposit.
     * @param to Address of the user that will receive the hTokens.
     * @param amount Amount of hTokens to be minted.
     * @param chainId Identifier of the Branch Chain.
     * @return Boolean indicating if the mint was successful.
     */
    function mint(address to, uint256 amount, uint256 chainId) external returns (bool);

    /**
     * @notice Function to burn hTokens in the Root Chain to match Branch Chain withdrawal.
     * @param from Address of the user that will burn the hTokens.
     * @param value Amount of hTokens to be burned.
     * @param chainId Identifier of the Branch Chain.
     */
    function burn(address from, uint256 value, uint256 chainId) external;

    /*///////////////////////////////////////////////////////////////
                                ERRORS 
    //////////////////////////////////////////////////////////////*/

    error UnrecognizedPort();
}
