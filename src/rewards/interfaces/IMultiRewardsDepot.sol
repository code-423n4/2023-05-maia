// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Multiple Rewards Depot
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice Holds multiple rewards to be distributed to Flywheel Rewards distributor contracts.
 *          When `getRewards()` is called by an added flywheel rewards, it transfers
 *          its balance of the associated assets to its flywheel rewards contract.
 *
 *             ⠉⠉⠉⠉⠉⠉⠉⠉⢉⠟⣩⠋⠉⠉⢩⠟⠉⣹⠋⡽⠉⠉⠉⠉⠉⠉⠉⠉⡏⠉⠉⠉⠉⠉⠉⠹⠹⡉⠉⠉⢙⠻⡍⠉⠉⠹⡍⠉⠉⠉
 *         ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠰⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡟⠀⠀⠀⠀⠀⠀⠀⠈⢻⡽⣄⠀⠀⠀⠙⣄⠀⠻⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢯⣎⢧⡀⠀⠀⠘⢦⠀⢹⡄⠀⢄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⠀⢀⣀⣠⣤⣶⠾⠷⠞⢿⡏⠻⣄⠀⠀⠈⢧⡀⢻⡄⠀⢆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣾⡾⠟⠛⠉⠁⠀⠀⠀⠀⠈⢳⡀⠈⢳⡀⠀⠀⠻⣄⢹⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣄⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀⠸⠉⢹⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢳⡀⠀⠙⢦⡀⠀⠘⢦⣻⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⢰⠀⠀⠀⠀⠀⠀⡆⠀⠀⢸⡀⠀⠀⠀⠀⠀⠀⠀⠈⡇⠀⠀⠈⣷⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠱⣄⠀⠀⠙⢦⡀⠀⠉⢻⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠁
 * ⠀⠀⠀⠀⠀⠀⠀⠀⢸⣟⠀⠀⠀⠀⣷⢣⣀⣀⠘⣧⠀⠀⠀⣶⠀⠀⠀⠀⢹⡄⠀⠀⠸⡆⠀⠀⠀⣀⣀⡤⠴⠶⠶⠶⠶⠘⠦⠤⣀⡀⠉⠳⢤⡀⢳⡀⠀⠀⠀⠀⠀⠀⠀⠀⡼
 * ⠀⠀⠀⠀⠀⠀⠀⠀⢸⡿⡆⠀⠀⠀⠸⣾⠉⠉⠁⢿⡆⠀⠀⠘⢧⠀⠀⠀⠀⢳⡀⠀⠀⢳⡴⠚⠉⢀⣀⢀⣠⣶⣶⣿⣿⣿⣿⣧⣤⣀⣀⠀⠀⠈⠓⢧⡀⠀⠀⠀⠀⠀⠀⢰⡁
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠠⣧⢿⡆⠀⠀⠀⡜⣇⠀⠀⠘⣿⣄⡀⠀⠈⢣⡀⠀⠀⠀⢻⣆⠀⠈⢷⡀⣺⢿⣾⣿⡿⠛⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⡀⠀⠈⢷⠀⠀⠀⠀⠀⢀⠿⠃
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀⢳⡀⠀⠀⢧⠈⢦⡀⠀⠘⣏⠛⣦⣀⣀⣙⠦⠤⢤⠤⠽⠗⠀⠀⢸⣭⣾⡿⠋⠀⣤⣤⣻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⡀⢸⠀⠀⠀⠀⠀⢀⣀⠀
 * ⠀⠀⠀⠀⠀⣦⠀⠀⠀⠘⡆⠀⢳⠲⣄⢘⣷⠬⣥⣄⡀⠈⠂⠀⠉⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠘⠛⠙⠃⠀⠀⣼⣿⣿⣿⡿⠿⠁⠛⢛⣿⣿⣿⣿⡟⣿⢺⠀⠀⠀⠀⠀⢸⣿⡇
 * ⠸⡄⢆⠀⠀⠈⣷⣄⠀⠀⠹⡆⢀⡴⠚⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠺⣿⣿⡿⠿⠀⠀⠀⠘⠿⢿⣿⣿⠇⠟⢨⠀⡄⠀⠀⠀⠀⢻⣷
 * ⢰⣳⡸⣧⡀⠀⠘⣿⣶⣄⣀⡿⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⣿⡀⢀⠀⢀⠐⠞⢀⣼⠿⠃⠀⠀⢸⣼⠁⠀⠀⠀⠀⠈⠏
 * ⠈⢇⠹⡟⠙⢦⡀⠘⣿⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⠿⠤⠴⠾⠟⠛⠉⠁⠀⠀⠀⠀⢸⠃⠀⠀⠀⠀⠀⢸⠀
 * ⢃⡘⣆⠘⣦⡀⠋⠀⠈⠛⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⠏⠀⠀⠀⠀⠀⠀⠟⠁
 * ⠀⣷⡘⣆⠈⢷⣄⡀⠀⠐⣽⡄⠀⠀⠀⢀⣠⣾⣿⣶⣶⣶⠶⠤⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠏⠀⠀⠀⠀⠀⠀⡀⠀⠀
 * ⠀⠉⢳⡘⢆⠈⢦⢁⡤⢄⡀⢷⡀⢀⢰⣿⡿⠟⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠁⠀⠀⠀⠀⠀⠀⠀⡄⠀⠀
 * ⠀⠀⢸⠛⣌⠇⠀⢻⠀⠀⠙⢎⢷⣀⡿⠟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⣿⣇
 * ⠀⠀⠀⠀⠈⢳⣄⡘⡆⠀⠀⠘⢧⡩⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⣿⠏⠈
 * ⠀⠀⠀⠀⠀⠀⡟⢽⣧⠀⠀⠀⠈⢿⣮⣳⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⡏⠀⠀
 * ⠀⠀⠀⠀⠀⣸⡇⠈⠹⣇⠀⠀⠀⠘⣿⡀⠈⠙⠒⠂⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣾⣿⠀⠀⠀
 * ⠀⠀⠀⠀⠀⣿⠁⠀⠀⢿⡀⠀⠀⠀⠹⡷⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⣴⣶⣾⣿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⣿⠃⠀⠀⠀
 * ⢷⡇⠀⠀⢠⠇⠀⠀⡄⢀⣇⠀⠀⠀⠀⢷⠹⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⡤⠤⠖⣚⣯⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⣿⡟⠀⠀⠀⠀
 * ⠀⠙⣦⠀⡜⠀⠀⢸⠁⣸⣻⡄⠀⠀⠀⠸⣇⢹⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⣤⣖⣞⣩⣥⣴⠶⠾⠟⠋⠄⠀⠀⠈⣿⡟⠀⠀⠀⠀⠀⠀⠀⠀⣠⣿⣿⡿⠀⠀⠀⠀⠀
 * ⠀⠀⠈⢳⡄⠀⢀⡟⢠⡇⠙⣇⠀⠀⠀⠀⢻⡀⠘⢧⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⢿⡏⢻⣇⠀⠀⠀⠀⠀⠀⣠⠞⡽⠁⠀⠀⠀⠀⠀⠀⠀⣼⣿⣿⣿⠃⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠙⣆⡘⠀⡞⠀⠀⢿⡀⠀⠀⠀⠀⣧⠀⠀⣿⢦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠦⡙⢦⣀⣀⡠⠴⢊⡡⠞⠁⠀⠀⠀⠀⠀⠀⢀⣾⣿⣿⣿⠇⠀⠀⠀⠀⠀⠀
 * ⢄⠀⠀⠀⠀⠈⠳⣼⠄⠀⢀⣼⣧⠀⠀⠀⠀⢸⣆⢠⡧⣼⠉⠳⢤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⠒⠶⠖⠊⣉⡀⠀⠀⠀⠀⠀⠀⠀⣰⣿⣿⣿⣿⠏⠀⠀⠀⠀⠀⠀⠠
 * ⠀⠳⡄⠀⠀⠀⠀⠙⢧⡀⢠⡿⢻⡀⠀⠀⠀⠀⢻⣤⠼⠿⠤⢤⣄⣈⡿⠲⠤⣄⣀⡤⠖⢶⠀⠀⠀⠀⠀⠀⠀⠈⠁⠀⠀⠀⠀⠀⠀⠀⢀⣾⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀⠂
 * ⠀⠀⠙⣄⠀⠀⠀⠀⠈⢳⣼⠃⢠⡇⠀⠀⠀⠀⠘⡇⠀⠀⠀⠀⠀⢉⡓⣶⣴⠞⠉⠀⢀⢻⣧⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠙⣧⠀⠀⠀⠀⠀⠹⣦⣶⢿⣦⠀⠀⠀⠀⠹⡄⠀⠀⠀⠀⣰⣿⡟⠁⠀⠀⢠⢿⣟⠛⠛⠛⠛⠒⠦⣤⣄⡀⠀⠀⢀⣠⣴⣿⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠐⠋⣧⠀⠀⠀⠀⠀⠈⠧⣼⢹⠀⠀⠀⠀⠀⢱⡀⠀⠀⢰⣿⡟⠀⠀⠀⢀⢏⣿⡙⠲⢦⣄⣀⡀⠀⠀⠀⣿⠋⠉⠹⣿⣿⣿⣿⣿⣿⣿⠟⠁⠀⠀⠀⠀⠀⡐⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⢳⡀⠀⠀⠀⠀⠀⡨⣉⡀⠈⠀⠀⠀⠀⢷⡀⠀⣾⡿⠀⠀⠀⠀⡞⣾⣿⣿⣷⣶⣤⣤⣭⣽⣶⣿⡏⠀⠀⠀⠹⢿⣿⣿⣿⠿⠋⠀⠀⠀⠀⢀⡴⠋⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⢀⣀⡞⢻⠃⣀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢳⣰⡿⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠀⠀⠀⠘⠛⢧⣄⡀⠀⠀⢀⣶⠞⠋⠀⠀⠀⠀⠀⠀⠀
 */
interface IMultiRewardsDepot {
    /*///////////////////////////////////////////////////////////////
                        GET REWARDS LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice returns available reward amount and transfer them to rewardsContract.
     *  @dev msg.sender needs to be an added Flywheel Rewards distributor contract.
     *       Transfers all associated assets to msg.sender.
     *  @return balance available reward amount for strategy.
     */
    function getRewards() external returns (uint256 balance);

    /*///////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Adds an asset to be distributed by a given contract.
     *  @param rewardsContract address of the rewards contract to attach the asset to.
     *  @param asset address of the asset to be distributed.
     */
    function addAsset(address rewardsContract, address asset) external;

    /**
     *  @notice Removes an asset from the reward contract that distributes the rewards.
     *  @param rewardsContract address of the contract to remove the asset from being distributed.
     */
    function removeAsset(address rewardsContract) external;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a new asset and rewards contract are added.
     * @param rewardsContract address of the rewards contract.
     * @param asset address of the asset to be distributed.
     */
    event AssetAdded(address indexed rewardsContract, address indexed asset);

    /**
     * @notice Emitted when an asset is removed from a rewards contract.
     * @param rewardsContract address of the rewards contract.
     * @param asset address of the asset to be distributed.
     */
    event AssetRemoved(address indexed rewardsContract, address indexed asset);

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error thrown when trying to add existing flywheel rewards or assets.
    error ErrorAddingAsset();

    /// @notice Error thrown when trying to remove non-existing flywheel rewards.
    error ErrorRemovingAsset();
}
