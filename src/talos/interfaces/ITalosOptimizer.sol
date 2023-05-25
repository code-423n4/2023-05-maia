// SPDX-License-Identifier: MIT
// Logic inspired by Popsicle Finance Contracts (PopsicleV3Optimizer/contracts/popsicle-v3-optimizer/OptimizerStrategy.sol)
pragma solidity ^0.8.0;

/**
 * @title  Talos Optimizer - Manages optimization variables for Talos Positions
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice Contains Optimizer variables used by Talos LPs that may only be modified by the governance.
 */
interface ITalosOptimizer {
    /// @return Maximum TLP value that could be minted
    function maxTotalSupply() external view returns (uint256);

    /// @notice Period of time that we observe for price slippage
    /// @return time in seconds
    function twapDuration() external view returns (uint32);

    /// @notice Maximum deviation of time weighted average price in ticks
    function maxTwapDeviation() external view returns (int24);

    /// @notice Tick multiplier for base range calculation
    function tickRangeMultiplier() external view returns (int24);

    /// @notice The price impact percentage during swap denominated in hundredths of a bip, i.e. 1e-6
    /// @return The max price impact percentage
    function priceImpactPercentage() external view returns (uint24);

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the total max supply which can only be changed by the governance address.
     *    @param _maxTotalSupply amount to set as max supply.
     */
    function setMaxTotalSupply(uint256 _maxTotalSupply) external;

    /**
     * @notice Sets the total twap duration which can only be changed by the governance address.
     * @param _twapDuration explicit twap duration in seconds
     */
    function setTwapDuration(uint32 _twapDuration) external;

    /**
     * @notice Sets the max twap deviation which can only be changed by the governance address.
     * @param _maxTwapDeviation explicit max twap devitation in ticks
     */
    function setMaxTwapDeviation(int24 _maxTwapDeviation) external;

    /**
     * @notice Function to set the tick range of a optimizer strategy
     * @param _tickRangeMultiplier Used to determine base order range
     */
    function setTickRange(int24 _tickRangeMultiplier) external;

    /**
     * @notice Function to change the price impact % of the optimizer strategy.
     * @param _priceImpactPercentage The price impact percentage during swap in hundredths of a bip, i.e. 1e-6
     */
    function setPriceImpact(uint24 _priceImpactPercentage) external;

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when the maxTotalSupply is zero
    error MaxTotalSupplyIsZero();

    /// @notice Thrown when the twapDuration is too low
    error TwapDurationTooLow();

    /// @notice Thrown when the maxTwapDeviation is too low
    error MaxTwapDeviationTooLow();

    /// @notice Thrown when the priceImpactPercentage is too high or too low
    error PriceImpactPercentageInvalid();
}
