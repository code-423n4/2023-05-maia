// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UlyssesPool} from "../UlyssesPool.sol";

/**
 * @title Ulysses Pool - Single Sided Stableswap LP
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice This contract is stableswap AMM that uses it's implemention of
 *          the Delta Algorithm to manage the LP's balances and transfers
 *          between LPs.
 *  @dev NOTE: Can't remove a destination, only add new ones.
 *
 *       Input: Transaction amount t, destination LP ID d
 *
 *       # On the source LP:
 *       1: aₛ ← aₛ + t
 *       2: bₛ,𝒹 ← bₛ,𝒹 − t
 *       3: for x != s do
 *       4:     diffₛ,ₓ ← max(0, lpₛ * wₛ,ₓ − lkbₓ,ₛ)
 *       5: end for
 *       6: Total ← ∑ₓ diffₛ,ₓ
 *       7: for x != s do
 *       8:     diffₛ,ₓ ← min(Total, t) * diffₛ,ₓ / Total
 *       9: end for
 *       10: t′ ← t - min(Total, t)
 *       11: for ∀x do
 *       12:     bₛ,ₓ ← bₛ,ₓ + diffₛ,ₓ + t′ * wₛ,ₓ
 *       13: end for
 *       14: msg = (t)
 *       15: Send msg to LP d
 *
 *       # On the destination LP:
 *       16: Receive (t) from a source LP
 *       17: if bₛ,𝒹 < t then
 *       18:     Reject the transfer
 *       19: end if
 *       20: a𝒹 ← a𝒹 − t
 *       21: bₛ,𝒹 ← bₛ,𝒹 − t
 *       Adapted from: Figure 4 from:
 *        - https://www.dropbox.com/s/gf3606jedromp61/Ulysses-Solving.The.Bridging-Trilemma.pdf?dl=0
 * ⠀⠀⠀⠀⠀⡂⠀⠀⠀⠁⠀⠀⠀⠀⠀⠄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⣀⡀⠀⠀⠀⣄⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠾⢋⣁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡄⢰⣿⠄
 * ⠀⠀⢰⠀⠀⠂⠔⠀⡂⠐⠀⠠⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⠤⢂⣉⠉⠉⠉⠁⠀⠉⠁⡀⠀⠉⠳⢶⠶⣦⣄⡀⠀⠀⠀⠀⠀⠀⠌⠙⠓⠒⠻⡦⠔⡌⣄⠤⢲⡽⠖⠪⢱⠦⣤
 * ⠀⠀⢀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⠘⠋⣠⣾⣛⣞⡛⢶⣾⣿⣶⣴⣤⣤⣤⣀⣀⢠⠂⠀⠊⡛⢷⣄⡀⠀⠀⠀⠀⠀⠂⣾⣁⢸⠀⠁⠐⢊⣱⣺⡰⠶⣚⡭⠂
 * ⢀⠀⠄⠀⠀⠀⠀⠈⠀⠀⠀⠀⠀⠀⠀⠀⠀⠄⠀⢠⣤⣴⡟⠇⣶⣠⢭⣿⣿⣿⣿⡌⠙⠻⠿⣿⣿⣿⣶⣄⡀⠀⠈⣯⢻⡷⣄⠀⠄⢀⡆⠠⢀⣤⠀⠀⠀⠀⠛⠐⢓⡁⠤⠐⢁
 * ⡼⠀⠀⢀⠆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⠆⠀⠀⣼⣿⣿⣿⣦⣠⠤⢖⣿⣿⣿⣟⣛⣿⡴⣿⣿⣿⣟⢿⣿⣿⣦⣰⠉⠻⢷⡈⢳⡄⢸⠇⢹⡦⢥⢸⠀⡄⠀⠀⠀⠈⠀⠀⢠⠂
 * ⢡⢐⠀⠂⠀⠀⠆⠀⠀⠀⠀⠀⠀⣠⠖⠋⢰⣴⣾⣿⣿⣿⣿⠙⠛⠚⠛⠁⠙⢦⡉⠉⠉⠀⠙⣷⣭⣿⣦⣹⣿⣿⣿⣤⠐⢀⠹⣷⡹⣾⣧⢻⠐⡀⢸⠀⠀⠀⡁⠀⠀⠀⠴⠃⠀
 * ⠂⠀⠀⠀⠈⡘⠀⠀⠀⠀⠀⠀⣰⠏⠀⢰⣾⡿⢋⣽⡿⠟⠉⠀⠀⢴⠀⠙⣆⠀⠳⡄⠀⠀⠀⠈⢿⣆⢹⣿⢿⣿⣿⣿⣆⣂⠀⢿⡇⠘⢿⣿⣷⡅⣼⢸⡇⢸⡇⠀⡀⣰⠁⠀⠀
 * ⠸⠐⠁⢠⠣⠁⠁⠀⠀⢀⣠⣾⡏⡄⣰⣿⣿⣷⣾⠁⠀⠀⠀⠀⠀⢸⡀⠀⠘⣇⠀⠙⣆⠀⠀⠀⠀⢻⣎⠻⣾⣿⣾⣿⣿⣿⠁⣸⣷⣀⠈⢿⣿⠇⡿⢸⡇⢸⠀⠀⣷⠁⠀⠀⠀
 * ⠂⠀⠀⡎⠄⠀⣠⣤⣾⣻⣿⡟⠀⢘⣿⣿⣿⡿⠃⠀⠀⠀⡄⠀⠀⢈⡇⠀⠀⠸⡀⠀⠀⠀⠀⠀⠀⠀⠻⡄⠀⢈⣿⠿⣿⣿⡿⠯⣿⡽⡆⠸⣿⣀⡇⢸⡇⢸⡀⠀⡟⠀⠀⠀⠀
 * ⡈⠀⡸⠼⠐⠌⢡⠹⡍⣷⣿⣁⠰⣾⣿⢿⣿⠁⠀⠀⠀⠀⡇⠀⠀⢸⠁⠀⠀⠀⢷⠀⠀⠀⠀⠀⠀⠀⠀⢷⠀⠈⣿⣿⣿⣿⣿⣛⣿⣿⡇⠀⢻⣻⡇⣼⡇⣹⠊⠀⣧⠀⠀⠀⠀
 * ⠀⢐⡣⢑⣨⠶⠞⠀⠃⣋⣽⣟⡘⣿⣿⣺⡿⠀⠀⠀⠀⠀⠁⠀⠀⠈⠀⠀⠀⠀⠈⡇⠐⡄⠀⠀⠀⠀⠀⠘⡆⡄⠈⠻⢿⣿⣿⣿⣿⣯⣜⠀⠀⡇⢧⣿⡇⣿⡄⢀⣿⠀⠀⠀⠀
 * ⠨⣥⡶⠌⣡⠡⡖⠀⠈⣹⣿⣿⣿⣿⣿⠏⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢳⡀⠀⠀⠀⠀⠀⣇⢷⠀⠀⠀⢼⣿⣿⣍⡟⠻⣷⣄⢻⡈⣿⠁⣿⡇⢸⣿⠀⠀⠀⠀
 * ⠋⠁⠀⠀⠁⠀⢩⡏⢼⣽⣿⣿⣿⣿⢷⡄⡇⠀⠀⠀⠀⠀⠀⡀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠸⣧⠀⠀⠀⠀⠀⢸⠸⡄⠀⠀⢸⣿⣿⣿⣿⣄⠙⣿⣾⡇⠸⡆⣿⠁⢸⣿⣇⠀⠀⠀
 * ⠀⠀⠠⢀⣪⣤⡌⠉⣼⣿⣿⣿⣿⣿⣨⡟⢣⠀⠀⠀⠀⠀⢠⣳⠃⠀⠀⠀⠀⠀⠀⠀⣄⠀⣿⡆⠀⠀⠀⠀⢸⡆⡇⠀⠀⢸⣾⣿⣿⣿⣿⣷⣼⣿⡇⠀⢹⣿⡅⣿⣿⣿⠀⠀⠀
 * ⣤⣵⣾⣿⣿⣿⣿⠂⠝⣿⣿⣿⣿⣿⣿⠀⠈⠀⠀⠀⠀⠀⣼⠋⠀⠀⠀⠀⠀⠀⠀⠀⢿⠀⡿⢣⠀⠀⠀⢀⡼⢻⢿⠀⠀⢸⣿⣿⣿⢿⢹⢿⣿⡅⢹⠀⠀⢿⡆⣿⣿⣿⡆⠀⠀
 * ⣿⣿⣿⣿⣿⣿⣿⣿⣾⣿⣿⣿⣿⣿⣿⣆⠀⡆⠀⠀⠀⣰⠋⠀⣆⠀⠀⠀⠀⠀⠀⠀⢸⣄⣧⣼⣦⡴⠚⢩⠇⠘⢺⣦⡆⢉⣿⣿⣿⣼⣾⡈⢻⣿⣸⡆⠀⠘⡇⣿⣿⣿⡇⠀⠀
 * ⡿⢿⣟⣽⣿⡿⠿⠛⣉⣥⠶⠾⣿⣿⣿⢿⠀⢳⡀⠀⢰⢋⡀⠀⢸⡄⠀⠀⠀⠀⠀⠀⣿⣇⠇⠀⣧⣧⡐⣍⣴⣾⣿⡇⠀⢸⣿⣿⠹⢿⣯⠻⢿⣿⣄⣧⠀⠀⠸⣿⣿⣿⣿⣆⠀
 * ⣿⠿⠟⣋⡡⠔⠚⠋⠁⠀⠀⠀⣧⣿⣿⡇⡆⠘⣧⡄⠀⠀⠉⠛⡓⣿⡎⠀⠀⠀⠀⠀⡿⢿⣄⡀⢹⣶⣿⠟⣻⠿⠚⣿⢀⣾⢾⣿⡀⣿⣿⠂⣺⡇⢻⣿⡆⠀⠀⢻⣿⣿⣿⣿⣆
 * ⢰⠚⠉⠀⡀⠀⠀⠀⠀⠀⠀⢰⣿⣿⣿⣷⡇⠀⢻⣿⣦⣀⢀⡀⢹⣌⣙⣶⠤⢄⣀⠤⠇⠀⠀⠀⠀⠋⠁⠀⠀⠀⠀⢸⣺⡏⡆⢻⣿⣿⣿⠀⣿⣧⢸⣯⢧⠀⠀⠀⢿⣿⣿⣿⣿
 * ⠂⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⠿⣿⣿⣿⣿⣧⠀⢸⣷⡀⠹⣿⡿⣟⠛⠻⣿⣿⣷⣦⠄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⣷⡇⠃⠘⣿⣿⣿⠀⣿⣿⢸⡟⠻⡄⠀⠀⠘⣿⣟⣟⣿
 * ⠀⠀⠀⠀⠀⠀⠀⢠⣾⠟⠁⢰⣿⣿⣿⣿⡟⡇⠀⡿⢻⠶⣄⠻⣄⠑⠶⠦⠶⠚⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠈⣼⡇⠀⠀⢹⣿⡿⢢⣿⣿⣿⣧⢠⢧⠀⠀⠀⠹⣯⣏⠀
 * ⠀⠀⠀⢦⠀⠀⠰⣿⣷⣀⣴⣿⡿⣻⣿⣿⡇⢧⠀⡇⠈⣧⠈⣿⢶⡿⡂⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣀⠀⠀⢠⣾⣿⡇⠀⠠⣿⢿⠀⣼⣿⣿⣿⣿⡎⣿⠀⠀⠀⠀⠹⡥⠀
 * ⠀⠀⠀⣼⣇⠀⠀⠈⠛⢫⣿⣿⢀⣏⣿⣿⡅⢸⣸⡇⠀⣿⡄⢹⠀⠙⣿⣦⠀⠀⠀⠀⠀⠀⠠⣤⡾⢅⡈⠓⠢⡶⠋⢀⡾⠁⢠⣇⣿⣧⣾⣿⣿⣿⣿⣿⣿⣮⣳⡀⠀⠀⠀⠰⠈
 * ⠀⠀⠀⣿⣿⡄⠀⠀⠀⠘⠻⣿⣾⠟⣿⣟⠀⠸⢃⠇⢰⣿⣇⠘⠀⠀⢻⣿⣷⣶⣤⣤⣀⣠⠞⠭⠤⠄⠙⠿⢻⣥⣴⣿⠃⠀⣾⣾⣿⣯⣿⣿⣿⣾⣟⣿⣿⣿⣿⡿⡄⠀⠀⠀⢣
 * ⠀⠀⠀⠻⣿⣿⣆⠀⠀⠀⢀⣼⣟⢠⣿⣿⠀⠀⢸⠀⣼⣿⣿⠆⠀⠀⢸⡟⣿⣿⣿⣿⠟⠁⠀⣀⣤⡖⠂⣴⣿⣯⣿⠋⠀⠐⡿⣹⣾⠋⠗⣯⢿⣿⣿⣿⣿⣿⣿⡇⢳⡀⠀⠀⠀
 * ⠀⠀⡂⢸⣿⣿⣿⣷⡀⢀⣿⣿⣿⣾⡿⣿⠀⠀⡜⢸⣿⣓⣾⣷⠀⠀⢸⣿⣜⣿⣯⡟⠀⠀⠀⣀⣈⠙⢶⣿⣿⣿⠇⠀⢀⣼⣇⣿⡀⢀⣤⣷⣿⣿⣿⣿⣿⣿⣿⡇⠀⠷⡀⠀⠀
 * ⣤⣀⡞⣢⣿⣿⣿⣿⣿⣾⣿⣿⣿⣿⠁⣿⡆⢠⣧⣿⡇⠐⣿⡿⠀⠀⢸⢷⣻⣿⡟⠀⠀⠀⠀⡇⣸⠑⢦⣻⣿⠏⠀⢀⣾⣿⣸⣿⣩⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠙⡣⠀⠀
 * ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠟⠃⣜⣿⣿⣧⣸⣿⠁⠀⠀⣿⣿⣿⡟⠀⠀⠀⠀⢰⣴⡟⠀⢀⡿⠃⠀⣠⠋⣹⡏⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠐⠤⠀
 * ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⠀⠀⣿⣿⣿⡦⣿⡟⠀⠀⣼⣿⣿⣿⠓⢤⣄⣤⣴⣿⣏⣀⣠⢾⠁⠀⡴⢇⣾⣿⢹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⢣
 * ⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⡻⠋⠻⠆⠀⠀⣰⣿⣿⣿⣿⣿⠇⠀⣾⣿⣿⡿⡇⠈⠒⠦⠖⢻⡟⠁⣰⠃⠈⠀⡼⢁⣼⣿⡇⣾⢈⣹⣹⣿⣿⣿⣿⣿⣿⣿⣿⣾⣿⣧⠀⠀⠀⠀⠀
 * ⣿⣿⣿⣿⣿⣿⣿⣿⢟⡵⠁⠀⠀⠀⢠⣲⠟⣿⣿⣿⣿⠏⣠⣾⣿⣿⣧⣰⠁⠀⠀⠀⠀⣾⠹⢾⠁⠀⣧⡾⣡⣾⡟⢻⡇⣿⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⣿⣿⣿⡆⠀⠀⠀⠀
 * ⣿⣿⣿⣿⣿⠿⠋⠀⠞⠀⠀⠀⠀⠀⣿⢏⡾⢃⣼⠟⣡⣾⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀⢠⢏⠀⢇⠀⠀⢸⣰⣿⣇⣗⣾⣇⢿⡿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡀⠀⠀⠀
 * ⢿⣿⠿⠋⣀⣤⠖⠀⠀⠀⠀⠀⠀⣼⣿⢏⣠⣞⣵⣿⣿⣿⣿⣿⣿⣟⣿⠁⠀⠀⠀⠀⣾⠀⠱⣼⡆⠀⢸⠹⣿⡄⣾⣿⣿⣿⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠈⢻⣿⡄⠀⠀
 */
interface IUlyssesPool {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The bandwidth state of a Ulysses LP
     * @param bandwidth The available bandwidth for the given pool's ID
     * @param weight The weight to calculate the target bandwidth for the given pool's ID
     * @param destination The destination Ulysses LP
     */
    struct BandwidthState {
        uint248 bandwidth;
        uint8 weight;
        UlyssesPool destination;
    }

    /**
     * @notice The fees charged to incentivize rebalancing
     *  @param lambda1 The fee charged for rebalancing in upper bound (in basis points divided 2)
     *  @param lambda2 The fee charged for rebalancing in lower bound (in basis points divided 2)
     *  @param sigma1 The bandiwth upper bound to start charging the first rebalancing fees
     *  @param sigma2 The bandiwth lower bound to start charging the second rebalancing fees
     */
    struct Fees {
        uint64 lambda1;
        uint64 lambda2;
        uint64 sigma1;
        uint64 sigma2;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the available bandwidth for the given pool's ID, if it doesn't have a connection it will return 0
     * @param destinationId The ID of a Ulysses LP
     * @return bandwidth The available bandwidth for the given pool's ID
     */

    function getBandwidth(uint256 destinationId) external view returns (uint256);

    /**
     * @notice Gets the bandwidth state list
     *  @return bandwidthStateList The bandwidth state list
     */
    function getBandwidthStateList() external view returns (BandwidthState[] memory);

    /**
     * @notice Calculates the amount of tokens that can be redeemed by the protocol.
     */
    function getProtocolFees() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sends all outstanding protocol fees to factory owner
     * @dev Anyone can call this function
     */
    function claimProtocolFees() external returns (uint256 claimed);

    /**
     * @notice Adds a new Ulysses LP with the requested weight
     * @dev Can't remove a destination, only add new ones
     * @param poolId The ID of the destination Ulysses LP to be added
     * @param weight The weight to calculate the bandwidth for the given pool's ID
     * @return index The index of bandwidthStateList of the newly added Ulysses LP
     */
    function addNewBandwidth(uint256 poolId, uint8 weight) external returns (uint256 index);

    /**
     * @notice Changes the weight of a exisiting Ulysses LP with the given ID
     * @param poolId The ID of the destination Ulysses LP to be removed
     * @param weight The new weight to calculate the bandwidth for the given pool's ID
     */
    function setWeight(uint256 poolId, uint8 weight) external;

    /**
     * @notice Sets the protocol and rebalancing fees
     * @param _fees The new fees to be set
     */
    function setFees(Fees calldata _fees) external;

    /**
     * @notice Sets the protocol fee
     * @param _protocolFee The new protocol fee to be set
     * @dev Only factory owner can call this function
     */
    function setProtocolFee(uint256 _protocolFee) external;

    /**
     * @notice Swaps from this Ulysses LP's underlying to the destination Ulysses LP's underlying.
     *       Distributes amount between bandwidths in the source, having a positive rebalancing fee
     *       Calls swapDestination of the destination Ulysses LP
     * @param amount The amount to be dsitributed to bandwidth
     * @param poolId The ID of the destination Ulysses LP
     * @return output The output amount transfered to user from the destination Ulysses LP
     */
    function swapIn(uint256 amount, uint256 poolId) external returns (uint256 output);

    /**
     * @notice Swaps from the caller (source Ulysses LP's) underlying to this Ulysses LP's underlying.
     *       Called from swapIn of the source Ulysses LP
     *       Removes amount from the source's bandwidth, having a negative rebalancing fee
     * @dev Only Ulysses LPs added as destinations can call this function
     * @param amount The amount to be removed from source's bandwidth
     * @param user The user to be transfered the output
     * @return output The output amount transfered to user
     */
    function swapFromPool(uint256 amount, address user) external returns (uint256 output);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Throw when trying to re-add pool or adding itself
    error InvalidPool();

    /// @notice Throw when trying to add a destination that is not a Ulysses LP
    error NotUlyssesLP();

    /// @notice Throw when fee would overflow
    error FeeError();

    /// @notice Throw when input amount is too small
    error AmountTooSmall();

    /// @notice Throw when weight is 0 or exceeds MAX_TOTAL_WEIGHT
    error InvalidWeight();

    /// @notice Throw when settng an invalid fee
    error InvalidFee();

    /// @notice Throw when weight is 0 or exceeds MAX_TOTAL_WEIGHT
    error TooManyDestinations();

    /// @notice Throw when adding/removing LPs before adding any destinations
    error NotInitialized();

    /// @notice Thrown when muldiv fails due to multiplication overflow
    error MulDivFailed();

    /// @notice Thrown when addition overflows
    error Overflow();

    /// @notice Thrown when subtraction underflows
    error Underflow();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a user swaps from this Ulysses LP's underlying to the destination Ulysses LP's underlying
     * @param caller The caller of the swap
     * @param poolId The ID of the destination Ulysses LP
     * @param assets The amount of underlying deposited in this Ulysses LP
     */
    event Swap(address indexed caller, uint256 indexed poolId, uint256 assets);
}
