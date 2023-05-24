// SPDX-License-Identifier: MIT
// Gauge weight logic inspired by Tribe DAO Contracts (flywheel-v2/src/token/ERC20Gauges.sol)
pragma solidity ^0.8.0;

/**
 * @title  An ERC20 with an embedded "Gauge" style vote with liquid weights
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice This contract is meant to be used to support gauge style votes with weights associated with resource allocation.
 *          Only after delegating to himself can a user allocate weight to a gauge.
 *          Holders can allocate weight in any proportion to supported gauges.
 *          A "gauge" is represented by an address that would receive the resources periodically or continuously.
 *
 *          For example, gauges can be used to direct token emissions, similar to Curve or Hermes V1.
 *          Alternatively, gauges can be used to direct another quantity such as relative access to a line of credit.
 *
 *          The contract's Ownable <https://github.com/Vectorized/solady/blob/main/src/auth/Ownable.sol> manages the gauge set and cap.
 *          "Live" gauges are in the set.
 *          Users can only add weight to live gauges but can remove weight from live or deprecated gauges.
 *          Gauges can be deprecated and reinstated; and will maintain any non-removed weight from before.
 *
 *  @dev    SECURITY NOTES: `maxGauges` is a critical variable to protect against gas DOS attacks upon token transfer.
 *          This must be low enough to allow complicated transactions to fit in a block.
 *
 *          Weight state is preserved on the gauge and user level even when a gauge is removed, in case it is re-added.
 *          This maintains the state efficiently, and global accounting is managed only on the `_totalWeight`
 */
interface IERC20Gauges {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice a struct representing a user's weight allocation to a gauge
     * @param storedWeight weight allocated to a gauge at the end of the last cycle
     * @param currentWeight current weight allocated to a gauge
     * @param currentCycle cycle in which the current weight was allocated
     */
    struct Weight {
        uint112 storedWeight;
        uint112 currentWeight;
        uint32 currentCycle;
    }

    /*///////////////////////////////////////////////////////////////
                            GAUGE STATE
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice a mapping from a user to their total allocated weight across all gauges
     */
    function getUserWeight(address) external view returns (uint112);

    /**
     * @notice the length of a gauge cycle
     */
    function gaugeCycleLength() external view returns (uint32);

    /**
     * @notice the period at the end of a cycle where votes cannot increment
     */
    function incrementFreezeWindow() external view returns (uint32);

    /**
     * @notice a mapping from users to gauges to a user's allocated weight to that gauge
     */
    function getUserGaugeWeight(address, address) external view returns (uint112);

    /*///////////////////////////////////////////////////////////////
                              VIEW HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice returns the end of the current cycle. This is the next unix timestamp which evenly divides `gaugeCycleLength`
     */
    function getGaugeCycleEnd() external view returns (uint32);

    /**
     * @notice returns the current weight of a given gauge
     * @param gauge address of the gauge to get the weight from
     */
    function getGaugeWeight(address gauge) external view returns (uint112);

    /**
     * @notice returns the stored weight of a given gauge. This is the snapshotted weight as-of the end of the last cycle.
     */
    function getStoredGaugeWeight(address gauge) external view returns (uint112);

    /**
     * @notice returns the current total allocated weight
     */
    function totalWeight() external view returns (uint112);

    /**
     * @notice returns the stored total allocated weight
     */
    function storedTotalWeight() external view returns (uint112);

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
     * @notice returns the set of gauges the user has allocated to, may be live or deprecated.
     */
    function userGauges(address user) external view returns (address[] memory);

    /**
     * @notice returns true if `gauge` is in user gauges
     */
    function isUserGauge(address user, address gauge) external view returns (bool);

    /**
     * @notice returns a paginated subset of gauges the user has allocated to, may be live or deprecated.
     *   @param user the user to return gauges from.
     *   @param offset the index of the first gauge element to read.
     *   @param num the number of gauges to return.
     */
    function userGauges(address user, uint256 offset, uint256 num) external view returns (address[] memory values);

    /**
     * @notice returns the number of user gauges
     */
    function numUserGauges(address user) external view returns (uint256);

    /**
     * @notice helper function for calculating the proportion of a `quantity` allocated to a gauge
     *  @param gauge the gauge to calculate the allocation of
     *  @param quantity a representation of a resource to be shared among all gauges
     *  @return the proportion of `quantity` allocated to `gauge`. Returns 0 if a gauge is not live, even if it has weight.
     */
    function calculateGaugeAllocation(address gauge, uint256 quantity) external view returns (uint256);

    /*///////////////////////////////////////////////////////////////
                        USER GAUGE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice increment a gauge with some weight for the caller
     *  @param gauge the gauge to increment
     *  @param weight the amount of weight to increment on a gauge
     *  @return newUserWeight the new user weight
     */
    function incrementGauge(address gauge, uint112 weight) external returns (uint112 newUserWeight);

    /**
     * @notice increment a list of gauges with some weights for the caller
     *  @param gaugeList the gauges to increment
     *  @param weights the weights to increment by
     *  @return newUserWeight the new user weight
     */
    function incrementGauges(address[] memory gaugeList, uint112[] memory weights)
        external
        returns (uint256 newUserWeight);

    /**
     * @notice decrement a gauge with some weight for the caller
     *  @param gauge the gauge to decrement
     *  @param weight the amount of weight to decrement on a gauge
     *  @return newUserWeight the new user weight
     */
    function decrementGauge(address gauge, uint112 weight) external returns (uint112 newUserWeight);

    /**
     * @notice decrement a list of gauges with some weights for the caller
     *  @param gaugeList the gauges to decrement
     *  @param weights the list of weights to decrement on the gauges
     *  @return newUserWeight the new user weight
     */
    function decrementGauges(address[] memory gaugeList, uint112[] memory weights)
        external
        returns (uint112 newUserWeight);

    /*///////////////////////////////////////////////////////////////
                        ADMIN GAUGE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice the default maximum amount of gauges a user can allocate to.
     * @dev if this number is ever lowered, or a contract has an override, then existing addresses MAY have more gauges allocated to. Use `numUserGauges` to check this.
     */
    function maxGauges() external view returns (uint256);

    /**
     * @notice an approved list for contracts to go above the max gauge limit.
     */
    function canContractExceedMaxGauges(address) external view returns (bool);

    /**
     * @notice add a new gauge. Requires auth by `authority`.
     */
    function addGauge(address gauge) external returns (uint112);

    /**
     * @notice remove a new gauge. Requires auth by `authority`.
     */
    function removeGauge(address gauge) external;

    /**
     * @notice replace a gauge. Requires auth by `authority`.
     */
    function replaceGauge(address oldGauge, address newGauge) external;

    /**
     * @notice set the new max gauges. Requires auth by `authority`.
     * @dev if this is set to a lower number than the current max, users MAY have more gauges active than the max. Use `numUserGauges` to check this.
     */
    function setMaxGauges(uint256 newMax) external;

    /**
     * @notice set the canContractExceedMaxGauges flag for an account.
     */
    function setContractExceedMaxGauges(address account, bool canExceedMax) external;

    /*///////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice emitted when incrementing a gauge
    event IncrementGaugeWeight(address indexed user, address indexed gauge, uint256 weight, uint32 cycleEnd);

    /// @notice emitted when decrementing a gauge
    event DecrementGaugeWeight(address indexed user, address indexed gauge, uint256 weight, uint32 cycleEnd);

    /// @notice emitted when adding a new gauge to the live set.
    event AddGauge(address indexed gauge);

    /// @notice emitted when removing a gauge from the live set.
    event RemoveGauge(address indexed gauge);

    /// @notice emitted when updating the max number of gauges a user can delegate to.
    event MaxGaugesUpdate(uint256 oldMaxGauges, uint256 newMaxGauges);

    /// @notice emitted when changing a contract's approval to go over the max gauges.
    event CanContractExceedMaxGaugesUpdate(address indexed account, bool canContractExceedMaxGauges);

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice thrown when trying to increment/decrement a mismatched number of gauges and weights.
    error SizeMismatchError();

    /// @notice thrown when trying to increment over the max allowed gauges.
    error MaxGaugeError();

    /// @notice thrown when incrementing over a user's free weight.
    error OverWeightError();

    /// @notice thrown when incrementing during the frozen window.
    error IncrementFreezeError();

    /// @notice thrown when trying to increment or remove a non-live gauge, or add a live gauge.
    error InvalidGaugeError();
}
