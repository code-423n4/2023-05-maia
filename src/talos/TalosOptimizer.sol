// SPDX-License-Identifier: MIT
// Logic inspired by Popsicle Finance Contracts (PopsicleV3Optimizer/contracts/popsicle-v3-optimizer/OptimizerStrategy.sol)
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {ITalosOptimizer} from "./interfaces/ITalosOptimizer.sol";

/// @title Talos Optimizer - Manages optimization variables for Talos Positions
contract TalosOptimizer is Ownable, ITalosOptimizer {
    /*//////////////////////////////////////////////////////////////
                        TALOS OPTIMIZER STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITalosOptimizer
    uint256 public override maxTotalSupply;
    /// @inheritdoc ITalosOptimizer
    uint32 public override twapDuration;
    /// @inheritdoc ITalosOptimizer
    int24 public override maxTwapDeviation;
    /// @inheritdoc ITalosOptimizer
    int24 public override tickRangeMultiplier;
    /// @inheritdoc ITalosOptimizer
    uint24 public override priceImpactPercentage;

    /**
     * @notice Constructor for Optimizer
     * @param _twapDuration TWAP duration in seconds for rebalance check
     * @param _maxTwapDeviation Max deviation from TWAP during rebalance
     * @param _tickRangeMultiplier Used to determine base order range
     * @param _priceImpactPercentage The price impact percentage during swap in hundredths of a bip, i.e. 1e-6
     * @param _maxTotalSupply Maximum TLP value that could be minted
     */
    constructor(
        uint32 _twapDuration,
        int24 _maxTwapDeviation,
        int24 _tickRangeMultiplier,
        uint24 _priceImpactPercentage,
        uint256 _maxTotalSupply,
        address _owner
    ) {
        if (_maxTwapDeviation < 20) revert MaxTwapDeviationTooLow();
        if (_twapDuration < 100) revert TwapDurationTooLow();
        if (_priceImpactPercentage >= 1e6 || _priceImpactPercentage == 0) {
            revert PriceImpactPercentageInvalid();
        }
        if (_maxTotalSupply == 0) revert MaxTotalSupplyIsZero();

        _initializeOwner(_owner);
        twapDuration = _twapDuration;
        maxTwapDeviation = _maxTwapDeviation;
        tickRangeMultiplier = _tickRangeMultiplier;
        priceImpactPercentage = _priceImpactPercentage;
        maxTotalSupply = _maxTotalSupply;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITalosOptimizer
    function setMaxTotalSupply(uint256 _maxTotalSupply) external onlyOwner {
        if (_maxTotalSupply == 0) revert MaxTotalSupplyIsZero();
        maxTotalSupply = _maxTotalSupply;
    }

    /// @inheritdoc ITalosOptimizer
    function setTwapDuration(uint32 _twapDuration) external onlyOwner {
        if (_twapDuration < 100) revert TwapDurationTooLow();
        twapDuration = _twapDuration;
    }

    /// @inheritdoc ITalosOptimizer
    function setMaxTwapDeviation(int24 _maxTwapDeviation) external onlyOwner {
        if (_maxTwapDeviation < 20) revert MaxTwapDeviationTooLow();
        maxTwapDeviation = _maxTwapDeviation;
    }

    /// @inheritdoc ITalosOptimizer
    function setTickRange(int24 _tickRangeMultiplier) external onlyOwner {
        tickRangeMultiplier = _tickRangeMultiplier;
    }

    /// @inheritdoc ITalosOptimizer
    function setPriceImpact(uint24 _priceImpactPercentage) external onlyOwner {
        if (_priceImpactPercentage >= 1e6 || _priceImpactPercentage == 0) {
            revert PriceImpactPercentageInvalid();
        }
        priceImpactPercentage = _priceImpactPercentage;
    }
}
