// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title  An ERC20 with an embedded attachment mechanism to keep track of boost allocations to gauges.
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice This contract is meant to be used to represent a token that can boost holders' rewards in other contracts.
 *          Holders can have their boost attached to gauges and cannot transfer their bHermes until they remove their boost.
 *          Only gauges can attach and detach boost from a user. The current user's boost and total supply are stored when attaching.
 *          The boost is then detached when the user removes their boost or when the gauge is removed.
 *          A "gauge" is represented by an address that distributes rewards to users periodically or continuously.
 *
 *          For example, gauges can be used to direct token emissions, similar to Curve or Hermes V1.
 *          Alternatively, gauges can be used to direct another quantity such as relative access to a line of credit.
 *          This contract should serve as reference for the amount of boost a user has allocated to a gauge.
 *          Then liquidity per user should be caculated by using this formula, from curve finance:
 *          min(UserLiquidity, (40 * UserLiquidity) + (60 * TotalLiquidity * UserBoostBalance / BoostTotal))
 *
 *          "Live" gauges are in the set.
 *          Users can only be attached to live gauges but can detach from live or deprecated gauges.
 *          Gauges can be deprecated and reinstated; and will maintain any non-removed boost from before.
 *
 *  @dev    SECURITY NOTES: decrementGaugeAllBoost can run out of gas.
 *          Gauges should be removed individually until decrementGaugeAllBoost can be called.
 *
 *          After having the boost attached, getUserBoost() will return the maximum boost a user had allocated to all gauges.
 *
 *          Boost state is preserved on the gauge and user level even when a gauge is removed, in case it is re-added.
 */
interface IERC20Boost {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice User allocated boost to a gauge and bHermes total supply.
     * @param userGaugeBoost User allocated boost to a gauge.
     * @param totalGaugeBoost bHermes total supply when a user allocated the boost.
     */
    struct GaugeState {
        uint128 userGaugeBoost;
        uint128 totalGaugeBoost;
    }

    /*///////////////////////////////////////////////////////////////
                            GAUGE STATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice User allocated boost to a gauge and the bHermes total supply.
     * @param user User address.
     * @param gauge Gauge address.
     * @return userGaugeBoost User allocated boost to a gauge.
     * @return totalGaugeBoost The bHermes total supply when a user allocated the boost.
     */
    function getUserGaugeBoost(address user, address gauge)
        external
        view
        returns (uint128 userGaugeBoost, uint128 totalGaugeBoost);

    /*///////////////////////////////////////////////////////////////
                            VIEW HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Maximum boost a user had allocated to all gauges since he last called decrementAllGaugesAllBoost().
     * @param user User address.
     * @return boost Maximum user allocated boost.
     */
    function getUserBoost(address user) external view returns (uint256 boost);

    /**
     * @notice returns the set of live gauges
     */
    function gauges() external view returns (address[] memory);

    /**
     * @notice returns a paginated subset of live gauges
     *   @param offset the index of the first gauge element to read
     *   @param num the number of gauges to return
     */
    function gauges(uint256 offset, uint256 num) external view returns (address[] memory values);

    /**
     * @notice returns true if `gauge` is not in deprecated gauges
     */
    function isGauge(address gauge) external view returns (bool);

    /**
     * @notice returns the number of live gauges
     */
    function numGauges() external view returns (uint256);

    /**
     * @notice returns the set of previously live but now deprecated gauges
     */
    function deprecatedGauges() external view returns (address[] memory);

    /**
     * @notice returns the number of live gauges
     */
    function numDeprecatedGauges() external view returns (uint256);

    /**
     * @notice returns the set of gauges the user has allocated to, they may be live or deprecated.
     */
    function freeGaugeBoost(address user) external view returns (uint256);

    /**
     * @notice returns the set of gauges the user has allocated to, they may be live or deprecated.
     */
    function userGauges(address user) external view returns (address[] memory);

    /**
     * @notice returns true if `gauge` is in user gauges
     */
    function isUserGauge(address user, address gauge) external view returns (bool);

    /**
     *  @notice returns a paginated subset of gauges the user has allocated to, they may be live or deprecated.
     *  @param user the user to return gauges from.
     *  @param offset the index of the first gauge element to read.
     *  @param num the number of gauges to return.
     */
    function userGauges(address user, uint256 offset, uint256 num) external view returns (address[] memory values);

    /**
     * @notice returns the number of user gauges
     */
    function numUserGauges(address user) external view returns (uint256);

    /*///////////////////////////////////////////////////////////////
                        GAUGE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice attach all user's boost to a gauge, only callable by the gauge.
     *  @param user the user to attach the gauge to.
     */
    function attach(address user) external;

    /**
     * @notice detach all user's boost from a gauge, only callable by the gauge.
     * @param user the user to detach the gauge from.
     */
    function detach(address user) external;

    /*///////////////////////////////////////////////////////////////
                        USER GAUGE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Update geUserBoost for a user, loop through all _userGauges
     * @param user the user to update the boost for.
     */
    function updateUserBoost(address user) external;

    /**
     * @notice Remove an amount of boost from a gauge
     * @param gauge the gauge to remove boost from.
     * @param boost the amount of boost to remove.
     */
    function decrementGaugeBoost(address gauge, uint256 boost) external;

    /**
     * @notice Remove all the boost from a gauge
     * @param gauge the gauge to remove boost from.
     */
    function decrementGaugeAllBoost(address gauge) external;

    /**
     * @notice Remove an amount of boost from all user gauges
     * @param boost the amount of boost to remove.
     */
    function decrementAllGaugesBoost(uint256 boost) external;

    /**
     * @notice Remove an amount of boost from all user gauges indexed
     * @param boost the amount of boost to remove.
     * @param offset the index of the first gauge element to read.
     * @param num the number of gauges to return.
     */
    function decrementGaugesBoostIndexed(uint256 boost, uint256 offset, uint256 num) external;

    /**
     * @notice Remove all the boost from all user gauges
     */
    function decrementAllGaugesAllBoost() external;

    /**
     * @notice add a new gauge. Requires auth by `authority`.
     */
    function addGauge(address gauge) external;

    /**
     * @notice remove a new gauge. Requires auth by `authority`.
     */
    function removeGauge(address gauge) external;

    /**
     * @notice replace a gauge. Requires auth by `authority`.
     */
    function replaceGauge(address oldGauge, address newGauge) external;

    /*///////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice emitted when adding a new gauge to the live set.
    event AddGauge(address indexed gauge);

    /// @notice emitted when removing a gauge from the live set.
    event RemoveGauge(address indexed gauge);

    /// @notice emmitted when a user attaches boost to a gauge.
    event Attach(address indexed user, address indexed gauge, uint256 boost);

    /// @notice emmitted when a user detaches boost from a gauge.
    event Detach(address indexed user, address indexed gauge);

    /// @notice emmitted when a user updates their boost.
    event UpdateUserBoost(address indexed user, uint256 updatedBoost);

    /// @notice emmitted when a user decrements their gauge boost.
    event DecrementUserGaugeBoost(address indexed user, address indexed gauge, uint256 UpdatedBoost);

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice thrown when trying to increment or remove a non-live gauge, or add a live gauge.
    error InvalidGauge();

    /// @notice thrown when a gauge tries to attach a position and already has one attached.
    error GaugeAlreadyAttached();

    /// @notice thrown when a gauge tries to transfer a position but does not have enough free balance.
    error AttachedBoost();
}
