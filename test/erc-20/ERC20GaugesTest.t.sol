// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";

import {MockBaseV2Gauge, FlywheelGaugeRewards, ERC20} from "../gauges/mocks/MockBaseV2Gauge.sol";

import {MockERC20Gauges, ERC20Gauges} from "./mocks/MockERC20Gauges.t.sol";

contract ERC20GaugesTest is DSTestPlus {
    MockERC20Gauges token;
    address gauge1;
    address gauge2;

    function setUp() public {
        token = new MockERC20Gauges(address(this), 3600, 600); // 1 hour cycles, 10 minute freeze

        hevm.mockCall(address(0), abi.encodeWithSignature("rewardToken()"), abi.encode(ERC20(address(0xDEAD))));
        hevm.mockCall(address(0), abi.encodeWithSignature("gaugeToken()"), abi.encode(ERC20Gauges(address(0xBEEF))));
        hevm.mockCall(
            address(this), abi.encodeWithSignature("bHermesBoostToken()"), abi.encode(ERC20Gauges(address(0xBABE)))
        );

        gauge1 = address(new MockBaseV2Gauge(FlywheelGaugeRewards(address(0)), address(0), address(0)));
        gauge2 = address(new MockBaseV2Gauge(FlywheelGaugeRewards(address(0)), address(0), address(0)));
    }

    /*///////////////////////////////////////////////////////////////
                        TEST ADMIN GAUGE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function testSetMaxGauges(uint256 max) public {
        token.setMaxGauges(max);
        assertEq(token.maxGauges(), max);
    }

    function testSetMaxGaugesNonOwner(uint256 max) public {
        hevm.prank(address(1));
        hevm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        token.setMaxGauges(max);
    }

    function testCanContractExceedMax() public {
        token.setContractExceedMaxGauges(address(this), true);
        assertTrue(token.canContractExceedMaxGauges(address(this)));
    }

    function testCanContractExceedMaxNonOwner() public {
        hevm.prank(address(1));
        hevm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        token.setContractExceedMaxGauges(address(this), true);
    }

    function testCanContractExceedMaxNonContract() public {
        hevm.expectRevert(abi.encodeWithSignature("NonContractError()"));
        token.setContractExceedMaxGauges(address(1), true);
    }

    function testAddGauge(address[8] memory gauges) public {
        token.setMaxGauges(8);

        uint256 uniqueGauges;
        for (uint256 i = 0; i < 8; i++) {
            if (token.isGauge(gauges[i]) || gauges[i] == address(0)) {
                hevm.expectRevert(abi.encodeWithSignature("InvalidGaugeError()"));
                token.addGauge(gauges[i]);
            } else {
                token.addGauge(gauges[i]);
                assertEq(token.numGauges(), uniqueGauges + 1);
                assertEq(token.gauges()[uniqueGauges], gauges[i]);
                uniqueGauges++;
            }
        }
    }

    function testAddPreviouslyDeprecated(uint112 amount) public {
        amount %= type(uint112).max;
        amount++;

        token.setMaxGauges(2);
        token.addGauge(gauge1);

        token.mint(address(this), amount);
        token.setMaxDelegates(1);
        token.delegate(address(this));
        token.incrementGauge(gauge1, amount);

        token.removeGauge(gauge1);
        token.addGauge(gauge1);

        assertEq(token.numGauges(), 1);
        assertEq(token.totalWeight(), amount);
        assertEq(token.getGaugeWeight(gauge1), amount);
        assertEq(token.getUserGaugeWeight(address(this), gauge1), amount);
        assertEq(token.deprecatedGauges().length, 0);
    }

    function testAddGaugeTwice() public {
        token.setMaxGauges(2);
        token.addGauge(gauge1);
        hevm.expectRevert(abi.encodeWithSignature("InvalidGaugeError()"));
        token.addGauge(gauge1);
    }

    function testAddGaugeNonOwner() public {
        token.setMaxGauges(1);
        hevm.prank(address(1));
        hevm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        token.addGauge(gauge1);
    }

    function testRemoveGauge() public {
        token.setMaxGauges(2);
        token.addGauge(gauge1);
        token.removeGauge(gauge1);
        assertEq(token.numGauges(), 1);
        assertEq(token.numDeprecatedGauges(), 1);
        assertEq(token.deprecatedGauges()[0], gauge1);
    }

    function testRemoveGaugeTwice() public {
        token.setMaxGauges(2);
        token.addGauge(gauge1);
        token.removeGauge(gauge1);
        hevm.expectRevert(abi.encodeWithSignature("InvalidGaugeError()"));
        token.removeGauge(gauge1);
    }

    function testRemoveGaugeNonOwner() public {
        token.setMaxGauges(2);
        token.addGauge(gauge1);
        hevm.startPrank(address(1));
        hevm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        token.removeGauge(gauge1);
    }

    function testRemoveGaugeWithWeight(uint112 amount) public {
        amount %= type(uint112).max;
        amount++;

        token.mint(address(this), amount);
        token.setMaxDelegates(1);
        token.delegate(address(this));

        token.setMaxGauges(2);
        token.addGauge(gauge1);
        token.incrementGauge(gauge1, amount);

        token.removeGauge(gauge1);
        assertEq(token.numGauges(), 1);
        assertEq(token.numDeprecatedGauges(), 1);
        assertEq(token.totalWeight(), 0);
        assertEq(token.getGaugeWeight(gauge1), amount);
        assertEq(token.getUserGaugeWeight(address(this), gauge1), amount);
    }

    function testReplaceGauge() public {
        token.setMaxGauges(2);
        token.addGauge(gauge1);
        token.replaceGauge(gauge1, gauge2);
        assertEq(token.numGauges(), 2);
        assertEq(token.numDeprecatedGauges(), 1);
        assertEq(token.gauges()[0], gauge1);
        assertEq(token.gauges()[1], gauge2);
        assertEq(token.deprecatedGauges()[0], gauge1);
    }

    function testReplaceGaugeNonOwner() public {
        token.setMaxGauges(2);
        token.addGauge(gauge1);
        hevm.startPrank(address(1));
        hevm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        token.replaceGauge(gauge1, gauge2);
    }

    /*///////////////////////////////////////////////////////////////
                        TEST USER GAUGE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function testCalculateGaugeAllocation() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(1);
        token.delegate(address(this));

        token.setMaxGauges(2);
        token.addGauge(gauge1);
        token.addGauge(gauge2);

        assertEq(token.incrementGauge(gauge1, 1e18), 1e18);
        assertEq(token.incrementGauge(gauge2, 1e18), 2e18);

        hevm.warp(3600); // warp 1 hour to store changes
        assertEq(token.calculateGaugeAllocation(gauge1, 100e18), 50e18);
        assertEq(token.calculateGaugeAllocation(gauge2, 100e18), 50e18);

        assertEq(token.incrementGauge(gauge2, 2e18), 4e18);

        // ensure updates don't propagate until stored
        assertEq(token.calculateGaugeAllocation(gauge1, 100e18), 50e18);
        assertEq(token.calculateGaugeAllocation(gauge2, 100e18), 50e18);

        hevm.warp(7200); // warp another hour to store changes again
        assertEq(token.calculateGaugeAllocation(gauge1, 100e18), 25e18);
        assertEq(token.calculateGaugeAllocation(gauge2, 100e18), 75e18);
    }

    function testIncrement(address[8] memory from, address[8] memory gauges, uint112[8] memory amounts) public {
        token.setMaxDelegates(8);
        token.setMaxGauges(8);
        unchecked {
            uint112 sum;
            for (uint256 i = 0; i < 8; i++) {
                gauges[i] = address(new MockBaseV2Gauge(FlywheelGaugeRewards(address(0)), address(0), address(0)));
                hevm.assume(
                    amounts[i] > 0 && sum + amounts[i] >= sum && !token.isGauge(gauges[i]) && gauges[i] != address(0)
                );
                sum += amounts[i];

                // Can't delegate to 0 address
                if (from[i] == address(0)) from[i] = address(0xCAFE);
                token.mint(from[i], amounts[i]);
                hevm.prank(from[i]);
                token.incrementDelegation(from[i], amounts[i]);

                uint112 userWeightBefore = token.getUserWeight(from[i]);
                uint112 userGaugeWeightBefore = token.getUserGaugeWeight(from[i], gauges[i]);
                uint112 gaugeWeightBefore = token.getGaugeWeight(gauges[i]);

                token.addGauge(gauges[i]);
                hevm.prank(from[i]);
                token.incrementGauge(gauges[i], amounts[i]);

                assertEq(token.getUserWeight(from[i]), userWeightBefore + amounts[i]);
                assertEq(token.totalWeight(), sum);
                assertEq(token.getUserGaugeWeight(from[i], gauges[i]), userGaugeWeightBefore + amounts[i]);
                assertEq(token.getGaugeWeight(gauges[i]), gaugeWeightBefore + amounts[i]);
            }
        }
    }

    function testIncrementDuringFreeze(uint112 amount, uint128 cycleOffset) public {
        hevm.assume(amount != 0);

        token.mint(address(this), amount);
        token.setMaxDelegates(1);
        token.delegate(address(this));
        token.setMaxGauges(1);
        token.addGauge(gauge1);

        // any timestamp in freeze window is unable to increment
        hevm.warp(token.getGaugeCycleEnd() - (cycleOffset % token.incrementFreezeWindow()) - 1);

        hevm.expectRevert(abi.encodeWithSignature("IncrementFreezeError()"));
        token.incrementGauge(gauge1, amount);
    }

    /// @notice test incrementing over user max
    function testIncrementOverMax() public {
        token.mint(address(this), 2e18);
        token.setMaxDelegates(1);
        token.delegate(address(this));

        token.setMaxGauges(1);
        token.addGauge(gauge1);
        token.addGauge(gauge2);

        token.incrementGauge(gauge1, 1e18);
        hevm.expectRevert(abi.encodeWithSignature("MaxGaugeError()"));
        token.incrementGauge(gauge2, 1e18);
    }

    /// @notice test incrementing at user max
    function testIncrementAtMax() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(1);
        token.delegate(address(this));

        token.setMaxGauges(1);
        token.addGauge(gauge1);
        token.addGauge(gauge2);

        token.incrementGauge(gauge1, 1e18);
        token.incrementGauge(gauge1, 1e18);

        assertEq(token.getUserGaugeWeight(address(this), gauge1), 2e18);
        assertEq(token.getUserWeight(address(this)), 2e18);
        assertEq(token.getGaugeWeight(gauge1), 2e18);
        assertEq(token.totalWeight(), 2e18);
    }

    /// @notice test incrementing over user max
    function testIncrementOverMaxApproved(address[8] memory gauges, uint112[8] memory amounts, uint8 max) public {
        token.setMaxDelegates(8);
        token.setMaxGauges(max % 8);
        token.setContractExceedMaxGauges(address(this), true);
        unchecked {
            uint112 sum;
            for (uint256 i = 0; i < 8; i++) {
                gauges[i] = address(new MockBaseV2Gauge(FlywheelGaugeRewards(address(0)), address(0), address(0)));
                hevm.assume(
                    amounts[i] > 0 && sum + amounts[i] >= sum && !token.isGauge(gauges[i]) && gauges[i] != address(0)
                );
                sum += amounts[i];

                token.mint(address(this), amounts[i]);
                hevm.prank(address(this));
                token.incrementDelegation(address(this), amounts[i]);

                uint112 userGaugeWeightBefore = token.getUserGaugeWeight(address(this), gauges[i]);
                uint112 gaugeWeightBefore = token.getGaugeWeight(gauges[i]);

                token.addGauge(gauges[i]);
                token.incrementGauge(gauges[i], amounts[i]);

                assertEq(token.getUserWeight(address(this)), sum);
                assertEq(token.totalWeight(), sum);
                assertEq(token.getUserGaugeWeight(address(this), gauges[i]), userGaugeWeightBefore + amounts[i]);
                assertEq(token.getGaugeWeight(gauges[i]), gaugeWeightBefore + amounts[i]);
            }
        }
    }

    /// @notice test incrementing and make sure weights are stored
    function testIncrementWithStorage() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(1);
        token.delegate(address(this));

        token.setMaxGauges(2);
        token.addGauge(gauge1);
        token.addGauge(gauge2);

        // gauge1,user1 +1
        assertEq(token.incrementGauge(gauge1, 1e18), 1e18);
        assertEq(token.getUserGaugeWeight(address(this), gauge1), 1e18);
        assertEq(token.getUserWeight(address(this)), 1e18);
        assertEq(token.getGaugeWeight(gauge1), 1e18);
        assertEq(token.totalWeight(), 1e18);

        assertEq(token.getStoredGaugeWeight(gauge1), 0);
        assertEq(token.storedTotalWeight(), 0);

        hevm.warp(block.timestamp + 3600); // warp one cycle

        assertEq(token.getStoredGaugeWeight(gauge1), 1e18);
        assertEq(token.storedTotalWeight(), 1e18);

        // gauge2,user1 +2
        assertEq(token.incrementGauge(gauge2, 2e18), 3e18);
        assertEq(token.getUserGaugeWeight(address(this), gauge2), 2e18);
        assertEq(token.getUserWeight(address(this)), 3e18);
        assertEq(token.getGaugeWeight(gauge2), 2e18);
        assertEq(token.totalWeight(), 3e18);

        assertEq(token.getStoredGaugeWeight(gauge2), 0);
        assertEq(token.storedTotalWeight(), 1e18);

        hevm.warp(block.timestamp + 1800); // warp half cycle

        assertEq(token.getStoredGaugeWeight(gauge2), 0);
        assertEq(token.storedTotalWeight(), 1e18);

        // gauge1,user1 +4
        assertEq(token.incrementGauge(gauge1, 4e18), 7e18);
        assertEq(token.getUserGaugeWeight(address(this), gauge1), 5e18);
        assertEq(token.getUserWeight(address(this)), 7e18);
        assertEq(token.getGaugeWeight(gauge1), 5e18);
        assertEq(token.totalWeight(), 7e18);

        hevm.warp(block.timestamp + 1800); // warp half cycle

        assertEq(token.getStoredGaugeWeight(gauge1), 5e18);
        assertEq(token.getStoredGaugeWeight(gauge2), 2e18);
        assertEq(token.storedTotalWeight(), 7e18);

        hevm.warp(block.timestamp + 3600); // warp full cycle

        assertEq(token.getStoredGaugeWeight(gauge1), 5e18);
        assertEq(token.getStoredGaugeWeight(gauge2), 2e18);
        assertEq(token.storedTotalWeight(), 7e18);
    }

    function testIncrementOnDeprecated(uint112 amount) public {
        token.setMaxGauges(2);
        token.addGauge(gauge1);
        token.removeGauge(gauge1);
        hevm.expectRevert(abi.encodeWithSignature("InvalidGaugeError()"));
        token.incrementGauge(gauge1, amount);
    }

    function testIncrementOverWeight(uint112 amount) public {
        amount %= type(uint112).max;
        amount++;

        token.setMaxGauges(2);
        token.addGauge(gauge1);
        token.addGauge(gauge2);

        hevm.assume(amount != type(uint112).max);
        token.mint(address(this), amount);
        token.setMaxDelegates(1);
        token.delegate(address(this));

        assertEq(token.incrementGauge(gauge1, amount), amount);
        hevm.expectRevert(abi.encodeWithSignature("OverWeightError()"));
        token.incrementGauge(gauge2, 1);
    }

    /// @notice test incrementing multiple gauges with different weights after already incrementing once
    function testIncrementGauges() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(1);
        token.delegate(address(this));

        token.setMaxGauges(2);
        token.addGauge(gauge1);
        token.addGauge(gauge2);

        token.incrementGauge(gauge1, 1e18);

        address[] memory gaugeList = new address[](2);
        uint112[] memory weights = new uint112[](2);
        gaugeList[0] = gauge2;
        gaugeList[1] = gauge1;
        weights[0] = 2e18;
        weights[1] = 4e18;

        assertEq(token.incrementGauges(gaugeList, weights), 7e18);

        assertEq(token.getUserGaugeWeight(address(this), gauge2), 2e18);
        assertEq(token.getGaugeWeight(gauge2), 2e18);
        assertEq(token.getUserGaugeWeight(address(this), gauge1), 5e18);
        assertEq(token.getUserWeight(address(this)), 7e18);
        assertEq(token.getGaugeWeight(gauge1), 5e18);
        assertEq(token.totalWeight(), 7e18);
    }

    function testIncrementGaugesDeprecated() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(1);
        token.delegate(address(this));

        token.setMaxGauges(2);
        token.addGauge(gauge1);
        token.addGauge(gauge2);
        token.removeGauge(gauge2);

        address[] memory gaugeList = new address[](2);
        uint112[] memory weights = new uint112[](2);
        gaugeList[0] = gauge2;
        gaugeList[1] = gauge1;
        weights[0] = 2e18;
        weights[1] = 4e18;
        hevm.expectRevert(abi.encodeWithSignature("InvalidGaugeError()"));
        token.incrementGauges(gaugeList, weights);
    }

    function testIncrementGaugesOver() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(1);
        token.delegate(address(this));

        token.setMaxGauges(2);
        token.addGauge(gauge1);
        token.addGauge(gauge2);

        address[] memory gaugeList = new address[](2);
        uint112[] memory weights = new uint112[](2);
        gaugeList[0] = gauge2;
        gaugeList[1] = gauge1;
        weights[0] = 50e18;
        weights[1] = 51e18;
        hevm.expectRevert(abi.encodeWithSignature("OverWeightError()"));
        token.incrementGauges(gaugeList, weights);
    }

    function testIncrementGaugesSizeMismatch() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(1);
        token.delegate(address(this));

        token.setMaxGauges(2);
        token.addGauge(gauge1);
        token.addGauge(gauge2);
        token.removeGauge(gauge2);

        address[] memory gaugeList = new address[](2);
        uint112[] memory weights = new uint112[](3);
        gaugeList[0] = gauge2;
        gaugeList[1] = gauge1;
        weights[0] = 1e18;
        weights[1] = 2e18;
        hevm.expectRevert(abi.encodeWithSignature("SizeMismatchError()"));
        token.incrementGauges(gaugeList, weights);
    }

    /// @notice test decrement twice, 2 tokens each after incrementing by 4.
    function testDecrement() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(1);
        token.delegate(address(this));

        token.setMaxGauges(2);
        token.addGauge(gauge1);
        token.addGauge(gauge2);

        assertEq(token.incrementGauge(gauge1, 4e18), 4e18);

        assertEq(token.decrementGauge(gauge1, 2e18), 2e18);
        assertEq(token.getUserGaugeWeight(address(this), gauge1), 2e18);
        assertEq(token.getUserWeight(address(this)), 2e18);
        assertEq(token.getGaugeWeight(gauge1), 2e18);
        assertEq(token.totalWeight(), 2e18);

        assertEq(token.decrementGauge(gauge1, 2e18), 0);
        assertEq(token.getUserGaugeWeight(address(this), gauge1), 0);
        assertEq(token.getUserWeight(address(this)), 0);
        assertEq(token.getGaugeWeight(gauge1), 0);
        assertEq(token.totalWeight(), 0);
    }

    /// @notice test decrement all removes user gauge.
    function testDecrementAllRemovesGauge() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(1);
        token.delegate(address(this));

        token.setMaxGauges(2);
        token.addGauge(gauge1);
        token.addGauge(gauge2);

        assertEq(token.incrementGauge(gauge1, 4e18), 4e18);

        assertEq(token.numUserGauges(address(this)), 1);
        assertEq(token.userGauges(address(this))[0], gauge1);

        assertEq(token.decrementGauge(gauge1, 4e18), 0);

        assertEq(token.numUserGauges(address(this)), 0);
    }

    /// @notice test decrement twice, 2 tokens each after incrementing by 4.
    function testDecrementWithStorage() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(1);
        token.delegate(address(this));

        token.setMaxGauges(2);
        token.addGauge(gauge1);
        token.addGauge(gauge2);

        assertEq(token.incrementGauge(gauge1, 4e18), 4e18);

        assertEq(token.decrementGauge(gauge1, 2e18), 2e18);
        assertEq(token.getUserGaugeWeight(address(this), gauge1), 2e18);
        assertEq(token.getUserWeight(address(this)), 2e18);
        assertEq(token.getGaugeWeight(gauge1), 2e18);
        assertEq(token.totalWeight(), 2e18);

        assertEq(token.getStoredGaugeWeight(gauge1), 0);
        assertEq(token.storedTotalWeight(), 0);

        hevm.warp(block.timestamp + 3600); // warp full cycle

        assertEq(token.getStoredGaugeWeight(gauge1), 2e18);
        assertEq(token.storedTotalWeight(), 2e18);

        assertEq(token.decrementGauge(gauge1, 2e18), 0);
        assertEq(token.getUserGaugeWeight(address(this), gauge1), 0);
        assertEq(token.getUserWeight(address(this)), 0);
        assertEq(token.getGaugeWeight(gauge1), 0);
        assertEq(token.totalWeight(), 0);

        assertEq(token.getStoredGaugeWeight(gauge1), 2e18);
        assertEq(token.storedTotalWeight(), 2e18);

        hevm.warp(block.timestamp + 3600); // warp full cycle

        assertEq(token.getStoredGaugeWeight(gauge1), 0);
        assertEq(token.storedTotalWeight(), 0);
    }

    function testDecrementOverWeight(uint112 amount) public {
        amount %= type(uint112).max;
        amount++;

        token.setMaxGauges(2);
        token.addGauge(gauge1);
        token.addGauge(gauge2);

        token.mint(address(this), amount);
        token.setMaxDelegates(1);
        token.delegate(address(this));

        hevm.assume(amount != type(uint112).max);

        assertEq(token.incrementGauge(gauge1, amount), amount);
        hevm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 17));
        token.decrementGauge(gauge1, amount + 1);
    }

    function testDecrementGauges() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(1);
        token.delegate(address(this));

        token.setMaxGauges(2);
        token.addGauge(gauge1);
        token.addGauge(gauge2);

        token.incrementGauge(gauge1, 1e18);

        address[] memory gaugeList = new address[](2);
        uint112[] memory weights = new uint112[](2);
        gaugeList[0] = gauge2;
        gaugeList[1] = gauge1;
        weights[0] = 2e18;
        weights[1] = 4e18;

        assertEq(token.incrementGauges(gaugeList, weights), 7e18);

        weights[1] = 2e18;
        assertEq(token.decrementGauges(gaugeList, weights), 3e18);

        assertEq(token.getUserGaugeWeight(address(this), gauge2), 0);
        assertEq(token.getGaugeWeight(gauge2), 0);
        assertEq(token.getUserGaugeWeight(address(this), gauge1), 3e18);
        assertEq(token.getUserWeight(address(this)), 3e18);
        assertEq(token.getGaugeWeight(gauge1), 3e18);
        assertEq(token.totalWeight(), 3e18);
    }

    function testDecrementGaugesOver() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(1);
        token.delegate(address(this));

        token.setMaxGauges(2);
        token.addGauge(gauge1);
        token.addGauge(gauge2);

        address[] memory gaugeList = new address[](2);
        uint112[] memory weights = new uint112[](2);
        gaugeList[0] = gauge2;
        gaugeList[1] = gauge1;
        weights[0] = 5e18;
        weights[1] = 5e18;

        assertEq(token.incrementGauges(gaugeList, weights), 10e18);

        weights[1] = 10e18;
        hevm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 17));
        token.decrementGauges(gaugeList, weights);
    }

    function testDecrementGaugesSizeMismatch() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(1);
        token.delegate(address(this));

        token.setMaxGauges(2);
        token.addGauge(gauge1);
        token.addGauge(gauge2);

        address[] memory gaugeList = new address[](2);
        uint112[] memory weights = new uint112[](2);
        gaugeList[0] = gauge2;
        gaugeList[1] = gauge1;
        weights[0] = 1e18;
        weights[1] = 2e18;

        assertEq(token.incrementGauges(gaugeList, weights), 3e18);
        hevm.expectRevert(abi.encodeWithSignature("SizeMismatchError()"));
        token.decrementGauges(gaugeList, new uint112[](0));
    }

    /*///////////////////////////////////////////////////////////////
                            TEST ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function testDecrementUntilFreeWhenFree() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(1);
        token.delegate(address(this));

        token.setMaxGauges(2);
        token.addGauge(gauge1);
        token.addGauge(gauge2);

        assertEq(token.incrementGauge(gauge1, 10e18), 10e18);
        assertEq(token.incrementGauge(gauge2, 20e18), 30e18);
        assertEq(token.userUnusedVotes(address(this)), 70e18);

        token.undelegate(address(this), 50e18);
        token.burn(address(this), 50e18);
        assertEq(token.userUnusedVotes(address(this)), 20e18);

        assertEq(token.getUserGaugeWeight(address(this), gauge1), 10e18);
        assertEq(token.getUserWeight(address(this)), 30e18);
        assertEq(token.getGaugeWeight(gauge1), 10e18);
        assertEq(token.getUserGaugeWeight(address(this), gauge2), 20e18);
        assertEq(token.getGaugeWeight(gauge2), 20e18);
        assertEq(token.totalWeight(), 30e18);
    }

    function testDecrementUntilFreeSingle() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(1);
        token.delegate(address(this));

        token.setMaxGauges(2);
        token.addGauge(gauge1);
        token.addGauge(gauge2);

        assertEq(token.incrementGauge(gauge1, 10e18), 10e18);
        assertEq(token.incrementGauge(gauge2, 20e18), 30e18);
        assertEq(token.userUnusedVotes(address(this)), 70e18);

        token.transfer(address(1), 80e18);
        assertEq(token.userUnusedVotes(address(this)), 0);

        assertEq(token.getUserGaugeWeight(address(this), gauge1), 0);
        assertEq(token.getUserWeight(address(this)), 20e18);
        assertEq(token.getGaugeWeight(gauge1), 0);
        assertEq(token.getUserGaugeWeight(address(this), gauge2), 20e18);
        assertEq(token.getGaugeWeight(gauge2), 20e18);
        assertEq(token.totalWeight(), 20e18);
    }

    function testDecrementUntilFreeDouble() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(1);
        token.delegate(address(this));

        token.setMaxGauges(2);
        token.addGauge(gauge1);
        token.addGauge(gauge2);

        assertEq(token.incrementGauge(gauge1, 10e18), 10e18);
        assertEq(token.incrementGauge(gauge2, 20e18), 30e18);
        assertEq(token.userUnusedVotes(address(this)), 70e18);

        token.approve(address(1), 100e18);
        hevm.prank(address(1));
        token.transferFrom(address(this), address(1), 90e18);

        assertEq(token.userUnusedVotes(address(this)), 0);

        assertEq(token.getUserGaugeWeight(address(this), gauge1), 0);
        assertEq(token.getUserWeight(address(this)), 0);
        assertEq(token.getGaugeWeight(gauge1), 0);
        assertEq(token.getUserGaugeWeight(address(this), gauge2), 0);
        assertEq(token.getGaugeWeight(gauge2), 0);
        assertEq(token.totalWeight(), 0);
        assertEq(token.freeVotes(address(this)), 10e18);
    }

    function testDecrementUntilFreeDeprecated() public {
        token.mint(address(this), 100e18);
        token.setMaxDelegates(1);
        token.delegate(address(this));

        token.setMaxGauges(2);
        token.addGauge(gauge1);
        token.addGauge(gauge2);

        assertEq(token.incrementGauge(gauge1, 10e18), 10e18);
        assertEq(token.incrementGauge(gauge2, 20e18), 30e18);
        assertEq(token.userUnusedVotes(address(this)), 70e18);

        assertEq(token.totalWeight(), 30e18);
        token.removeGauge(gauge1);
        assertEq(token.totalWeight(), 20e18);

        token.burn(address(this), 100e18);

        assertEq(token.userUnusedVotes(address(this)), 0);

        assertEq(token.getUserGaugeWeight(address(this), gauge1), 0);
        assertEq(token.getUserWeight(address(this)), 0);
        assertEq(token.getGaugeWeight(gauge1), 0);
        assertEq(token.getUserGaugeWeight(address(this), gauge2), 0);
        assertEq(token.getGaugeWeight(gauge2), 0);
        assertEq(token.totalWeight(), 0);
    }
}
