// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";

import {ITalosOptimizer, TalosOptimizer} from "@talos/TalosOptimizer.sol";

// Full integration tests across Flywheel Core, Flywheel Gauge Rewards and bHermes
contract TalosOptimizerTest is DSTestPlus {
    TalosOptimizer optimizer;

    uint256 maxTotalSupply = type(uint256).max;
    uint32 twapDuration = 100;
    int24 maxTwapDeviation = 40;
    int24 tickRangeMultiplier = 16;
    uint24 priceImpactPercentage = 2000;

    function setUp() public {
        optimizer = new TalosOptimizer(
            twapDuration,
            maxTwapDeviation,
            tickRangeMultiplier,
            priceImpactPercentage,
            maxTotalSupply,
            address(this)
        );
    }

    function testGetTwapDuration() public {
        assertEq(optimizer.twapDuration(), twapDuration);
    }

    function testGetMaxTwapDeviation() public {
        assertEq(optimizer.maxTwapDeviation(), maxTwapDeviation);
    }

    function testGetTickRangeMultiplier() public {
        assertEq(optimizer.tickRangeMultiplier(), tickRangeMultiplier);
    }

    function testGetPriceImpactPercentage() public {
        assertEq(optimizer.priceImpactPercentage(), priceImpactPercentage);
    }

    function testGetMaxTotalSupply() public {
        assertEq(optimizer.maxTotalSupply(), maxTotalSupply);
    }

    function testSetTwapDuration() public {
        uint32 newTwapDuration = 200;
        optimizer.setTwapDuration(newTwapDuration);
        assertEq(optimizer.twapDuration(), newTwapDuration);
    }

    function testSetMaxTwapDeviation() public {
        int24 newMaxTwapDeviation = 80;
        optimizer.setMaxTwapDeviation(newMaxTwapDeviation);
        assertEq(optimizer.maxTwapDeviation(), newMaxTwapDeviation);
    }

    function testSetTickRange() public {
        int24 newTickRangeMultiplier = 32;
        optimizer.setTickRange(newTickRangeMultiplier);
        assertEq(optimizer.tickRangeMultiplier(), newTickRangeMultiplier);
    }

    function testSetPriceImpact() public {
        uint24 newPriceImpactPercentage = 4000;
        optimizer.setPriceImpact(newPriceImpactPercentage);
        assertEq(optimizer.priceImpactPercentage(), newPriceImpactPercentage);
    }

    function testSetMaxTotalSupply() public {
        uint256 newMaxTotalSupply = 1000;
        optimizer.setMaxTotalSupply(newMaxTotalSupply);
        assertEq(optimizer.maxTotalSupply(), newMaxTotalSupply);
    }

    function testSetMaxTotalSupplyZero() public {
        hevm.expectRevert(ITalosOptimizer.MaxTotalSupplyIsZero.selector);
        optimizer.setMaxTotalSupply(0);
    }

    function testSetTwapDurationTooLow(uint32 newTwapDuration) public {
        newTwapDuration %= 100;

        hevm.expectRevert(ITalosOptimizer.TwapDurationTooLow.selector);
        optimizer.setTwapDuration(newTwapDuration);
    }

    function testSetMaxTwapDeviationTooLow(int24 newMaxTwapDeviation) public {
        newMaxTwapDeviation %= 20;

        hevm.expectRevert(ITalosOptimizer.MaxTwapDeviationTooLow.selector);
        optimizer.setMaxTwapDeviation(newMaxTwapDeviation);
    }

    function testSetPriceImpactInvalid() public {
        uint24 newPriceImpactPercentage = 0;

        hevm.expectRevert(ITalosOptimizer.PriceImpactPercentageInvalid.selector);
        optimizer.setPriceImpact(newPriceImpactPercentage);
    }

    function testSetPriceImpactInvalid(uint24 newPriceImpactPercentage) public {
        newPriceImpactPercentage %= type(uint24).max - 1e6;
        newPriceImpactPercentage += 1e6;

        hevm.expectRevert(ITalosOptimizer.PriceImpactPercentageInvalid.selector);
        optimizer.setPriceImpact(newPriceImpactPercentage);
    }

    function testSetMaxTotalSupplyNotOwner() public {
        hevm.expectRevert(Ownable.Unauthorized.selector);
        hevm.prank(address(1));
        optimizer.setMaxTotalSupply(maxTotalSupply);
    }

    function testSetTwapDurationNotOwner() public {
        hevm.expectRevert(Ownable.Unauthorized.selector);
        hevm.prank(address(1));
        optimizer.setTwapDuration(twapDuration);
    }

    function testSetMaxTwapDeviationNotOwner() public {
        hevm.expectRevert(Ownable.Unauthorized.selector);
        hevm.prank(address(1));
        optimizer.setMaxTwapDeviation(maxTwapDeviation);
    }

    function testSetTickRangeNotOwner() public {
        hevm.expectRevert(Ownable.Unauthorized.selector);
        hevm.prank(address(1));
        optimizer.setTickRange(tickRangeMultiplier);
    }

    function testSetPriceImpactNotOwner() public {
        hevm.expectRevert(Ownable.Unauthorized.selector);
        hevm.prank(address(1));
        optimizer.setPriceImpact(priceImpactPercentage);
    }
}
