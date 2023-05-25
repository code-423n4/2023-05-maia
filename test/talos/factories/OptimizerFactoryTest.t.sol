// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";

import "../mocks/MockOptimizerFactory.sol";

error Unauthorized();

contract OptimizerFactoryTest is DSTestPlus {

    MockOptimizerFactory factory;

    function setUp() public {
        factory = new MockOptimizerFactory();
    }

    function testConstructor() public {
        assertEq(factory.getOptimizers().length, 1);
        assertEq(address(factory.optimizers(0)), address(0));
    }

    function testCreateTalosOptimizer(
        uint32 twapDuration,
        int24 maxTwapDeviation,
        int24 tickRangeMultiplier,
        uint24 priceImpactPercentage,
        uint256 maxTotalSupply,
        address owner
    ) public {
        hevm.assume(owner != address(0));
        hevm.assume(maxTwapDeviation >= 20);
        hevm.assume(twapDuration >= 100);
        hevm.assume(priceImpactPercentage < 1e6 && priceImpactPercentage != 0);
        hevm.assume(maxTotalSupply != 0);

        factory.createTalosOptimizer(
            twapDuration,
            maxTwapDeviation,
            tickRangeMultiplier,
            priceImpactPercentage,
            maxTotalSupply,
            owner
        );

        assertEq(factory.optimizerIds(factory.optimizers(1)), 1);
    }

    function testGetOptimizers(
        uint32 twapDuration,
        int24 maxTwapDeviation,
        int24 tickRangeMultiplier,
        uint24 priceImpactPercentage,
        uint256 maxTotalSupply,
        address owner
    ) public {
        assertEq(factory.getOptimizers().length, 1);
        testCreateTalosOptimizer(twapDuration, maxTwapDeviation, tickRangeMultiplier, priceImpactPercentage, maxTotalSupply, owner);
        assertEq(factory.getOptimizers().length, 2);
    }

    function testCreateBoostAggregatorIds(
        uint32 twapDuration,
        int24 maxTwapDeviation,
        int24 tickRangeMultiplier,
        uint24 priceImpactPercentage,
        uint256 maxTotalSupply,
        address owner,
        uint32 twapDuration2,
        int24 maxTwapDeviation2,
        int24 tickRangeMultiplier2,
        uint24 priceImpactPercentage2,
        uint256 maxTotalSupply2,
        address owner2
    ) public {
        hevm.assume(owner != address(0) && owner2 != address(0) && owner != owner2);
        hevm.assume(twapDuration != twapDuration2);
        hevm.assume(maxTwapDeviation != maxTwapDeviation2);
        hevm.assume(tickRangeMultiplier != tickRangeMultiplier2);
        hevm.assume(priceImpactPercentage != priceImpactPercentage2);
        hevm.assume(maxTotalSupply != maxTotalSupply2);

        testCreateTalosOptimizer(twapDuration, maxTwapDeviation, tickRangeMultiplier, priceImpactPercentage, maxTotalSupply, owner);
        testCreateTalosOptimizer(twapDuration2, maxTwapDeviation2, tickRangeMultiplier2, priceImpactPercentage2, maxTotalSupply2, owner2);

        TalosOptimizer optimizer = factory.optimizers(1);
        assertEq(factory.optimizerIds(optimizer), 1);
        assertEq(optimizer.owner(), owner);
        TalosOptimizer optimizer2 = factory.optimizers(2);
        assertEq(factory.optimizerIds(optimizer2), 2);
        assertEq(optimizer2.owner(), owner2);
    }
}