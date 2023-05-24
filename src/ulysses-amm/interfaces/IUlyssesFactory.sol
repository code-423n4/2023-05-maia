// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

/**
 * @title Factory of new Ulysses instances
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice This contract is responsible for creating new Ulysses Tokens
 *          and Ulysses Pools.
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⡴⠲⠚⠙⢛⣶⣶⣯⣷⣒⠶⣍⠀⠂⠀⠀⠉⠉⠒⢦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⡾⠁⠀⢠⣶⠟⠛⠿⠟⠛⠣⣍⠙⠒⢷⣦⡀⠀⠀⠀⠀⠀⠈⠲⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣾⠟⠀⢀⡴⠋⠀⣠⣾⠟⠙⢧⠀⠀⢱⠀⠀⠀⠙⢦⡀⠀⠀⠀⠀⠀⠈⠳⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⡿⠃⠀⢠⡞⠀⢠⣴⣏⡞⠀⠀⠈⡇⠀⠀⢷⠀⠀⠀⠀⠙⢦⠀⠀⠀⠀⠀⠀⠙⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⣰⠋⣠⠀⠀⡾⠀⢠⠏⡇⣼⠃⠀⠀⠀⢸⠀⠀⠈⡆⢰⡀⠀⠀⠀⢳⡀⠀⠀⠀⠀⠀⠈⢆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⢰⠟⣄⡇⠀⣸⠁⠀⠁⢸⠀⠋⠀⠀⠀⠀⠀⣇⠀⠀⡇⠀⢣⠀⠀⠀⠀⢧⠀⠀⠀⢀⠀⠀⠘⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⣿⣾⢹⡧⢪⡇⠀⠀⠀⣿⠀⠀⠀⠀⠀⠀⠀⢻⠀⠀⠀⢀⠘⣇⠀⠀⠀⠘⣆⠀⠀⠈⠀⠀⠀⠹⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⢰⣻⣯⠟⠁⢸⠁⠀⠀⢰⡉⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀⢸⡀⠀⠀⠀⢹⡀⠀⠀⠀⠀⠀⠀⢧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⣾⣿⠁⣸⠀⡇⠀⠀⠀⣾⣇⠀⢧⠀⠀⠀⠀⠀⠀⠀⠀⡆⠀⡇⠀⣷⠀⠀⡄⠀⡇⠀⠀⠀⢀⠀⠀⣾⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⢠⣿⡇⠀⣾⠀⡇⠀⠀⣄⣿⣽⠀⢸⡆⠀⠀⠀⠀⠀⡄⢠⠇⠀⣿⡀⣿⡇⠀⢱⠀⢹⠀⠀⠀⢸⠀⠀⢱⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⢸⠁⡇⠀⡟⡆⡇⡄⠀⣹⠟⠸⣳⠈⢷⡄⠀⠀⠀⢠⢧⡟⠀⡆⣿⡇⢸⢻⡀⠘⣇⢸⡇⠀⠀⢸⡆⠀⢸⢻⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⢸⣧⠇⢀⠁⢻⣷⡇⠀⡯⠤⠖⢳⡏⠙⣧⣀⠀⢠⣿⣿⡄⠀⣷⠋⡇⠈⠉⢧⠀⡿⣜⡇⠀⠀⢸⡇⠀⠀⡏⡄⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⢸⡿⠀⢻⠀⠸⣷⣧⢰⠁⠀⠀⠀⢳⣀⡟⣷⢴⡿⢻⣿⡇⣸⡟⢀⡁⠀⠀⠈⡀⠁⢻⡇⢰⠀⢸⡇⠀⠀⢰⡇⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⢀⣸⡿⡀⠘⡆⠀⢿⣟⣿⠠⠤⣄⠀⠀⠀⠈⠊⠿⣦⣟⠏⣧⠟⠛⣩⣤⣤⣦⣬⣵⣦⣼⣇⡼⠀⣼⠁⢰⠀⠘⡇⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⢀⣾⢿⡟⡇⠀⢷⠱⢼⣿⠾⢿⣿⣿⣿⣿⡷⣄⠀⠀⠈⠉⠀⠃⠠⠞⢻⣿⣿⣿⣿⠋⠁⡟⢩⡇⠀⡿⠀⣾⠀⠀⠁⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⢀⣾⠏⢸⠁⢳⠀⢘⣇⠀⢽⠀⠈⠻⣿⣗⣿⠃⠈⠀⠀⠀⠀⠀⠀⠀⠀⠈⢻⣯⣛⡥⠀⠀⢠⡿⠁⢸⠁⠀⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⣾⡟⠀⢸⡀⢸⡆⠀⢻⣆⠘⣆⠀⠀⠈⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣴⠟⡵⢀⣿⠀⢀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⢸⢽⠃⢀⣼⡇⠘⣿⠀⢸⣿⡣⣙⡅⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡜⠁⡼⢃⣾⡏⠀⣸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠸⢼⣧⣴⣿⣿⠀⢿⣟⢆⢳⡫⣿⣝⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⠀⠀⠀⠀⠐⠁⢠⠞⣠⡾⡟⠀⢰⠿⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⢙⣿⣿⣿⠀⢸⠘⣞⣎⢧⠈⢻⠷⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠁⠀⠀⠀⠀⣠⠞⠋⠔⢩⠰⠁⢀⡞⠀⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⣿⣿⡆⠸⡇⢸⣞⢯⣧⢈⠀⢈⠓⠦⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⡾⠁⠀⠇⢀⡇⠀⢀⣼⠀⠀⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⢀⡀⠀⡇⣿⢧⠀⡇⢸⡌⢳⡙⢦⠍⡞⠀⠀⠀⠹⡗⠦⢄⣀⣀⣀⡴⠚⠁⢈⣇⢀⠀⢀⡾⠀⠀⣾⠈⡇⠀⢿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⣸⡇⢀⢧⣿⠻⣆⣿⣾⡇⠸⣽⡎⢵⠃⠀⠀⠀⣠⡧⠂⠀⠀⠁⠀⠀⠀⠀⣸⠻⣄⡆⢘⡇⠀⣸⣿⢰⠇⢸⡈⠀⣄⠄⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠈⢹⡇⡸⣿⣿⣷⠥⠐⠈⢹⡄⣿⣀⣚⣀⡤⠖⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠀⠈⠙⣺⠁⣰⣿⣿⣾⣿⠀⠓⣇⣿⠸⡆⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠐⠙⢳⣤⣿⣿⠁⠀⠀⣠⡤⢷⢿⡞⠉⠁⠀⠀⠀⠀⠀⢲⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⢿⠀⣿⣿⣿⡷⡿⡅⠀⠀⠉⠲⢧⣄⠀⠀⠀⠀⠀⠀
 * ⠀⠀⡰⡏⠁⣾⡟⠀⠀⣸⣿⣵⣼⣷⣧⠀⠀⡘⢦⣄⠀⠀⠀⢇⠀⠀⠀⠀⠀⠀⠀⣀⣀⡟⠀⠀⣿⣿⠂⢹⡍⠀⠀⠀⠀⠀⣸⣟⠷⡄⠀⠀⠀⠀
 * ⠀⠸⡷⠃⣰⣿⣁⡤⢴⡷⠻⣯⣿⠹⢯⢦⠀⠳⡀⠨⠍⠛⠲⣾⣄⡠⢖⡾⠗⠋⠉⣠⣿⣰⢠⠀⢉⣿⣲⣸⠀⠀⠁⠀⠀⢻⠇⠈⢹⣇⠀⠀⠀⠀
 * ⠀⢰⠇⠈⠉⣠⠞⠀⡞⠀⠲⣿⡇⢢⡈⠻⡳⠤⠽⣦⣀⣀⠀⠀⠉⠛⠉⠀⠀⣀⡴⠋⠃⡏⠘⡆⠸⢿⣿⡿⠀⠀⠀⠘⢀⡟⠀⠀⢘⣿⣦⡀⠀⠀
 * ⣰⣿⣤⠤⠄⡇⠀⣸⠁⠀⠀⢟⠀⠀⠑⠦⣝⠦⣄⠀⠈⠉⠀⠀⠀⠀⠀⠐⠚⠁⠀⣴⢸⡇⠀⣇⠀⠸⣿⠁⠀⠀⠀⢀⣾⠁⠀⣠⢾⣿⡅⠉⡂⠄
 * ⢹⢻⡄⠀⠀⣣⢠⢇⡀⠀⠀⣹⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣼⡇⠠⢿⠀⠀⢿⡇⠀⠀⢀⡼⠁⠀⠞⣡⠞⢯⢿⡄⢠⡀
 * ⣸⡧⢳⡀⠀⣿⡾⠉⠀⠐⢻⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⡇⣿⠀⢻⡀⠀⢸⣇⡀⢹⣿⠃⣀⡴⣾⠁⠀⠘⢺⣷⡇⡀
 * ⡿⡃⠈⢳⣴⠏⠀⠀⠀⣠⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢷⡘⡷⣄⢳⡀⠈⣿⢳⡀⠻⣿⡉⠉⠁⠀⠀⠀⠈⡏⡇⣷
 * ⣟⠁⠠⢴⣿⣦⣀⣀⣴⣿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠙⢮⠳⢽⣦⣾⣇⠱⣄⢈⣻⣄⠀⠀⠀⠀⠀⣧⡇⢹
 */
interface IUlyssesFactory {
    /**
     * @notice Creates a new Ullysses pool based on a given ERC20 passed through params.
     *     @param asset represents the asset we want to create a Ulysses pool around
     *     @return poolId returns the poolId
     */
    function createPool(ERC20 asset, address owner) external returns (uint256);

    /**
     * @notice Takes an array of assets and their respective weights and creates a Ulysses token.
     *         First it creates a Ulysses pool for each asset and then it links them together
     *         according to the specified weight.
     * @param assets ERC20 array that represents all the assets that are part of the Ulysses Token.
     * @param weights Weights array that holds the weights for the corresponding assets.
     */
    function createPools(ERC20[] calldata assets, uint8[][] calldata weights, address owner)
        external
        returns (uint256[] memory poolIds);

    /**
     * @notice Responsible for creating a unified liquidity token (Ulysses token).
     *  @param poolIds Ids of the pools that the unified liquidity token should take into consideration
     *  @param weights wWeights of the pools to link to the Ulysses Token
     *  @return _tokenId Id of the newly created Ulysses token
     */
    function createToken(uint256[] calldata poolIds, uint256[] calldata weights, address owner)
        external
        returns (uint256 _tokenId);
}
