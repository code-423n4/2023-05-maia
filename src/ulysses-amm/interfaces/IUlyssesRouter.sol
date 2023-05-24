// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UlyssesFactory} from "../factories/UlyssesFactory.sol";

/**
 * @title Ulysses Router - Handles routing of transactions in the Ulysses AMM
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice This contract routes and adds/removes liquidity from Ulysses Pools
 *          deployed by the Ulysses Factory, it allows users to set maximum slippage.
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠞⠉⢀⣶⠞⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠑⠢⣝⣦⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠞⠁⠀⢠⣿⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠻⣷⡀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡴⠞⠁⠀⠀⢠⣿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⢷⡄⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⢀⡴⠋⠀⠀⠀⠀⢀⣿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢻⡄⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⣸⠁⢀⡴⠃⠀⠀⣼⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣷⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢧⡀⠀⠀⢻⡄⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⢰⡏⢠⠞⠀⠀⠀⢠⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡄⠀⠀⠀⢹⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⣄⠀⠀⢳⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⣼⣱⠋⠀⠀⠀⠀⠸⠀⠀⢀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⢰⠀⠀⠀⣿⡄⠀⠀⠀⠀⠀⠐⠦⡀⠀⠀⠀⠀⠀⠀⠀⠸⣧⠀⠸⡇⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⣿⠇⠀⠀⠀⠀⠀⠀⠀⢀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⡇⢸⠀⠀⠀⣿⣷⣄⠀⠀⠀⠀⠀⠀⠈⢦⡀⠀⠀⠀⠀⠀⠀⠸⣧⢀⣇⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⢸⠯⠀⠀⠀⠀⠀⠀⠀⠀⣼⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣇⠈⡇⠀⠀⢻⡀⠙⠷⣄⠀⠀⠀⠀⠀⠀⠹⣦⠀⠀⠀⠀⠀⠀⣿⣿⣿⡆⠀⠀
 * ⠀⠀⠀⠀⠀⢠⡟⠀⠀⠀⢀⡄⠀⠀⠀⢠⡏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣽⠇⢻⡄⡇⠀⠀⢸⣷⡀⠀⠈⠳⢄⠀⠀⠀⠀⠀⠘⣆⠀⠀⠀⠀⠀⢨⣿⣿⣇⠀⠀
 * ⠀⠀⠀⠀⠀⡞⠀⠀⠀⢀⡞⠀⠀⠀⠀⣾⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⣿⠀⠘⣇⡇⠀⠀⢸⡌⠻⣷⣤⡀⠀⠉⠀⠀⠀⠀⠀⠘⣧⠀⠀⠀⠀⣿⣿⣿⣿⡀⠀
 * ⠀⠀⠀⠀⣼⠁⠀⠀⠀⣼⠃⠀⠀⠀⢠⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡇⣰⡟⠀⠀⢹⡇⠀⠀⣼⠇⠀⠸⣍⠉⠙⠶⢤⣀⡀⠀⠀⠀⠘⡆⠀⠀⢠⣿⣿⣿⣿⡇⠀
 * ⠀⠀⠀⢰⣣⠃⢰⠁⢀⡇⠀⠀⠀⠀⢸⣽⠀⢠⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⢠⠏⡇⠀⠀⠸⡇⠀⠀⢻⠀⠀⠀⠈⢿⡲⢄⠀⠀⠈⣄⠀⠀⠀⠸⡆⠀⢸⣿⣿⣿⣿⡇⠀
 * ⠀⠀⢠⣧⡟⠀⡼⠀⢸⠀⠀⠀⠀⠀⣿⡿⡄⢸⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⢀⣏⡟⢰⠇⠀⠀⢰⠇⠀⢰⣾⠀⠀⠀⠀⠀⢸⣟⣦⣄⠀⠈⠻⣧⣄⠀⠹⠀⢸⣿⣿⣿⣿⣿⠀
 * ⠀⠰⡫⢻⠁⢰⡇⠀⡞⠀⢠⠂⢀⠀⡿⠀⡇⠘⡆⠀⠀⠀⠀⠘⣆⠀⠀⠀⢸⡿⠀⣾⠀⠀⠀⢸⢀⠀⣼⣾⠀⠀⠀⠀⠀⠀⠻⣌⠙⠿⣦⡀⠘⢿⣦⠀⠀⢸⣿⣿⣿⣿⣿⠀
 * ⠀⠀⠀⣼⠀⣾⠃⢰⡇⠀⡞⠀⢸⠀⡇⠀⢻⡄⡇⠀⠀⠀⠀⠀⢻⠀⠀⠀⣿⠁⠀⡏⠀⠀⠀⣸⡎⢠⡏⢏⡆⠀⠀⠀⠀⠀⠀⠙⢯⡶⣄⡈⠒⠀⠹⣧⠀⢻⣿⣿⣿⣿⣿⠀
 * ⠀⠀⠀⡇⢰⣿⠀⣼⡇⢠⡇⠀⢸⡄⡇⠀⠀⢻⣻⡀⠰⡀⠀⠀⠈⣇⠀⢸⡟⠓⢺⠓⠶⠦⢤⣿⢁⣾⣀⣈⣻⡀⠀⠀⠀⠀⠀⠀⠈⢿⡑⠛⠷⣤⠀⠘⠄⠀⢻⣿⣿⣿⣿⠀
 * ⠀⠀⠀⡇⡾⢯⠀⣿⡇⢸⡇⠀⢸⣇⡧⠤⠤⠒⠻⣇⠀⢳⡀⠀⠀⠸⡆⢸⠁⠀⡞⠀⠀⠀⣸⢇⠞⠁⠀⠀⠈⠳⠄⠀⠀⠀⠀⠀⠀⢀⣽⣍⢓⣮⣷⣄⡀⠀⠀⠻⣿⣿⡇⠀
 * ⠀⠀⠀⣇⡇⢸⠀⡿⣇⢸⣧⠀⢸⢿⣳⠀⣀⣀⡀⠙⣦⠈⣷⡄⠀⠀⠹⣼⠀⣰⠃⠀⠔⢺⣏⣉⣩⣽⣂⣀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠊⣤⣾⠛⢁⣴⣮⣷⠀⠀⠀⠯⠿⡇⠀
 * ⠀⠀⠀⢹⡇⠘⣧⣧⣹⣜⢿⠀⣾⣀⢻⣷⣭⣭⣍⣑⠊⢧⡘⡟⢦⡀⠀⠹⡤⠃⠀⢀⣀⣬⡿⢿⣿⣿⣿⣿⣿⣶⣶⣤⣤⠀⠀⢰⢇⡾⠉⣠⠞⠛⡏⠹⣽⡇⠀⠀⠀⠀⣿⠀
 * ⠀⠀⠀⠀⢳⡼⠋⣻⣿⠉⠻⣇⣿⡿⣿⡟⢻⠿⣿⣿⣿⣭⡳⣿⣄⠙⢾⣦⡹⣄⠀⠀⠀⠀⠀⠀⣥⣼⠛⣿⣿⣿⣿⣹⠏⠀⢀⣿⡞⠀⣼⢛⢷⠀⡇⠀⢸⡇⠀⢰⠀⢧⢸⠀
 * ⠀⠀⠀⠀⣼⠁⣰⢃⡇⡰⠀⢹⣾⡿⡌⠳⠀⢰⣿⣟⣿⡿⡅⠀⠉⠁⠀⠈⠉⠺⠧⠀⠀⠀⠀⠀⠘⢯⣋⣉⡉⣹⠓⠃⠀⠀⢸⠞⠀⠀⣝⢁⡾⠀⠁⢀⡾⠁⠀⠘⠀⠸⣾⠀
 * ⠀⠀⠀⡸⠁⣰⠃⢸⣧⠇⠀⢸⠀⠙⢿⣆⠀⠀⠉⠳⠤⠤⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠛⠛⠋⠀⠀⠀⠀⢼⠀⠀⣀⣼⡿⠀⠀⣠⡞⠀⠀⠀⠀⡇⠀⢹⠀
 * ⠀⠀⣰⠇⣴⠃⠀⣼⡞⠀⠀⢸⠀⠀⠀⢻⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⠀⠰⠿⠝⠋⣡⣾⠋⠀⠀⠀⠀⠀⡇⠀⢸⠀
 * ⠀⢀⡿⣴⠋⠀⠀⣿⠃⠀⠀⣿⡀⠀⠀⠀⣷⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣠⣴⣾⡿⠃⠀⠀⠀⠀⠀⠀⡇⠀⠀⡇
 * ⠀⢸⣴⠇⠀⠀⢰⠇⠀⠀⢰⠿⡇⠀⡀⠀⢸⣇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⣿⡿⠋⡇⣿⠀⠀⢀⠀⠀⠀⠀⠀⡇⠀⠀⢱
 * ⢠⣏⠏⠀⠀⢀⡞⠀⠀⢠⡞⠀⡇⢸⠀⠀⠀⢿⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⡿⣿⡇⣸⡹⢻⠀⠀⡸⠀⠀⠀⠀⠀⡇⠀⠀⠘
 * ⢸⢻⠀⠀⠀⡾⠀⠀⠀⣾⠃⢠⡇⣼⠀⠀⠀⠘⣷⡀⠀⠀⠀⠀⠀⠀⠀⢀⣀⡤⠴⠶⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣾⠋⠀⣸⣧⣏⡇⢸⠀⢀⡇⠀⠀⠀⠀⠀⡇⠀⠀⠀
 * ⡾⡸⠀⠀⣼⠁⠀⠀⣸⡟⠀⣾⣇⡟⠀⠀⠀⠀⢻⡷⣄⠀⣴⠒⠒⠒⠚⠛⠥⠤⠤⢤⣜⣯⢧⠀⠀⠀⠀⠀⠀⠀⣰⠋⠀⠀⠀⣿⠉⣽⢧⢸⠇⢸⠁⠀⠀⠀⠀⠀⡇⢀⠁⠀
 * ⠀⡇⠀⣰⠁⠀⠀⣼⠃⡇⢀⣇⣿⠁⠀⠀⠀⠀⢀⠇⢺⣿⠃⠀⠈⠑⠒⠲⠦⠤⣤⣀⠸⡈⢻⡀⠀⠀⠀⢀⣠⠞⠁⠀⠀⠀⠀⢻⡷⠃⠘⣿⣆⡏⠀⠀⠀⠀⠀⠀⡇⠘⠀⢀
 * ⠀⡇⣠⠇⠀⠀⣴⠁⢀⣇⡼⣿⠃⠀⠀⠀⠀⢀⡞⠀⣼⡏⠀⠀⠀⣀⠀⠀⠀⠀⠀⠈⢧⢷⡼⠁⠀⣀⣶⡟⠁⠀⠀⠀⠀⠀⢠⠞⠁⠀⠀⠘⣿⠃⠀⠀⠀⠀⠀⠀⡇⠀⠀⠜
 * ⠀⣧⠋⠀⠀⣼⣷⣾⣍⣁⠀⠁⠀⠀⠀⢀⡤⠏⢀⣴⣿⠁⠀⠀⠀⠀⠙⠓⠲⠤⣄⠀⢸⣼⣣⣴⣾⠿⠋⠀⠀⠀⠀⠀⢀⡴⠋⠀⠀⠀⠀⢰⡇⠀⠀⠀⠀⠀⠀⠀⢁⣀⣼⡤
 * ⠀⠃⠀⢀⡾⡉⠀⠀⢹⣏⠛⠶⢤⣴⣾⣯⣤⡶⢿⣿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⣇⢀⣿⣿⠟⠁⠀⠀⠀⠀⠀⣀⡴⠟⠁⠀⠀⠀⠀⢀⣾⠀⠀⠀⠀⠀⠀⠀⠀⡿⠀⠀⠀
 */
interface IUlyssesRouter {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice A route for a swap
     * @param from The index of the pool to swap from
     * @param to The index of the pool to swap to
     */
    struct Route {
        uint128 from;
        uint128 to;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the Ulysses Factory address
     * @return ulyssesFactory The Ulysses Factory address
     */
    function ulyssesFactory() external view returns (UlyssesFactory);

    /**
     * @notice Adds liquidity to a pool
     * @param amount The amount of tokens to add
     * @param minOutput The minimum amount of LP tokens to receive
     * @param poolId The pool to add liquidity to
     * @return lpReceived amount of LP tokens received
     */
    function addLiquidity(uint256 amount, uint256 minOutput, uint256 poolId) external returns (uint256);

    /**
     * @notice Removes liquidity from a pool
     * @param amount The amount of LP tokens to remove
     * @param minOutput The minimum amount of tokens to receive
     * @param poolId The pool to remove liquidity from
     * @return tokensReceived amount of tokens received
     */
    function removeLiquidity(uint256 amount, uint256 minOutput, uint256 poolId) external returns (uint256);

    /**
     * @notice Swaps tokens from one pool to another
     * @param amount The amount of tokens to swap
     * @param minOutput The minimum amount of tokens to receive
     * @param routes The routes to take for the swap to occur
     * @return tokensReceived amount of tokens received
     */
    function swap(uint256 amount, uint256 minOutput, Route[] calldata routes) external returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the output amount is less than the minimum output amount
    error OutputTooLow();

    /// @notice Thrown when the Ulysses pool is not recognized
    error UnrecognizedUlyssesLP();
}
