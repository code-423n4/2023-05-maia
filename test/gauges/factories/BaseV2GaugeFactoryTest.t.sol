// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";

import "../mocks/MockBaseV2GaugeFactory.sol";

error Unauthorized();

contract BaseV2GaugeFactoryTest is DSTestPlus {
    address gaugeManager = address(0xCAFE);
    address _bHermesBoost = address(0xBCAA);
    address bribesFactory = address(0x12DC);

    MockBaseV2GaugeFactory factory;

    function setUp() public {
        factory = new MockBaseV2GaugeFactory(
            BaseV2GaugeManager(gaugeManager),
            bHermesBoost(_bHermesBoost),
            BribesFactory(bribesFactory),
            address(this)
        );
    }

    function mockAddGauge(address gauge) public {
        hevm.mockCall(gaugeManager, abi.encodeWithSignature("addGauge(address)"), abi.encode(gauge));
    }

    function mockRemoveGauge(address gauge) public {
        hevm.mockCall(gaugeManager, abi.encodeWithSignature("removeGauge(address)"), abi.encode(gauge));
    }

    function mockStrategy(address gauge) public {
        // HEVM address: cant be mocked (https://github.com/dapphub/dapptools/blob/master/src/hevm/README.md)
        hevm.assume(address(gauge) != address(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D));
        hevm.mockCall(gauge, abi.encodeWithSignature("strategy()"), abi.encode(gauge));
    }

    function mockBribesFactoryOwner(address owner) public {
        hevm.mockCall(bribesFactory, abi.encodeWithSignature("owner()"), abi.encode(owner));
    }

    function mockAddBribeToGauge(address gauge) public {
        // HEVM address: cant be mocked (https://github.com/dapphub/dapptools/blob/master/src/hevm/README.md)
        hevm.assume(address(gauge) != address(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D));
        mockBribesFactoryOwner(address(this));
        hevm.mockCall(bribesFactory, abi.encodeWithSignature("flywheelTokens(address)"), abi.encode(gauge));

        hevm.mockCall(gauge, abi.encodeWithSignature("addBribeFlywheel(address)"), "");

        hevm.mockCall(bribesFactory, abi.encodeWithSignature("addGaugetoFlywheel(address, address)"), "");
    }

    function mockRemoveBribeFromGauge(address gauge) public {
        // HEVM address: cant be mocked (https://github.com/dapphub/dapptools/blob/master/src/hevm/README.md)
        hevm.assume(address(gauge) != address(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D));
        mockBribesFactoryOwner(address(this));
        hevm.mockCall(bribesFactory, abi.encodeWithSignature("flywheelTokens(address)"), abi.encode(gauge));

        hevm.mockCall(gauge, abi.encodeWithSignature("removeBribeFlywheel(address)"), "");
    }

    function mockNewEpoch(address gauge) public {
        hevm.mockCall(gauge, abi.encodeWithSignature("newEpoch()"), "");
    }

    function testNewEpoch(uint80 gauge) public {
        address gauge1 = address(uint160(gauge));
        address gauge2 = address(uint160(gauge) + 1);

        testCreateGauge(gauge1);

        factory.changeActiveGauge(BaseV2Gauge(gauge1), false);

        factory.newEpoch();

        testCreateGauge(gauge2);

        mockNewEpoch(gauge2);

        hevm.expectCall(gauge2, abi.encodeWithSignature("newEpoch()"));
        factory.newEpoch();
    }

    function testNewEpochRangeSetup(uint80 gauge) public returns (address, address) {
        address gauge1 = address(uint160(gauge));
        address gauge2 = address(uint160(gauge) + 1);
        address gauge3 = address(uint160(gauge) + 2);
        address gauge4 = address(uint160(gauge) + 3);

        testCreateGauge(gauge1);
        testCreateGauge(gauge2);

        factory.changeActiveGauge(BaseV2Gauge(gauge1), false);
        factory.changeActiveGauge(BaseV2Gauge(gauge2), false);

        factory.newEpoch(0, 2);
        factory.newEpoch(0, 10);
        factory.newEpoch(1, 10);

        testCreateGauge(gauge3);
        testCreateGauge(gauge4);

        factory.newEpoch(0, 2);
        factory.newEpoch(1, 2);

        mockNewEpoch(gauge3);
        mockNewEpoch(gauge4);

        return (gauge3, gauge4);
    }

    function testNewEpochRangeBoth(uint80 gauge) public {
        (address gauge3, address gauge4) = testNewEpochRangeSetup(gauge);

        hevm.expectCall(gauge3, abi.encodeWithSignature("newEpoch()"));
        hevm.expectCall(gauge4, abi.encodeWithSignature("newEpoch()"));
        factory.newEpoch(0, 4);
    }

    function testNewEpochRangeSingle(uint80 gauge) public {
        (address gauge3, address gauge4) = testNewEpochRangeSetup(gauge);

        factory.changeActiveGauge(BaseV2Gauge(gauge3), false);
        hevm.expectCall(gauge4, abi.encodeWithSignature("newEpoch()"));
        factory.newEpoch(0, 4);
    }

    function testNewEpochRangeOver(uint80 gauge) public {
        (address gauge3, address gauge4) = testNewEpochRangeSetup(gauge);

        hevm.expectCall(gauge3, abi.encodeWithSignature("newEpoch()"));
        hevm.expectCall(gauge4, abi.encodeWithSignature("newEpoch()"));
        factory.newEpoch(0, 10);
    }

    function testNewEpochRangeUnder(uint80 gauge) public {
        (address gauge3, address gauge4) = testNewEpochRangeSetup(gauge);

        hevm.expectCall(gauge3, abi.encodeWithSignature("newEpoch()"));
        hevm.expectCall(gauge4, abi.encodeWithSignature("newEpoch()"));
        factory.newEpoch(2, 4);
    }

    function testNewEpochRangeOverUnder(uint80 gauge) public {
        (address gauge3, address gauge4) = testNewEpochRangeSetup(gauge);

        hevm.expectCall(gauge3, abi.encodeWithSignature("newEpoch()"));
        hevm.expectCall(gauge4, abi.encodeWithSignature("newEpoch()"));
        factory.newEpoch(2, 10);
    }

    function testCreateGauge(address strategy) public {
        hevm.assume(strategy != address(0));
        mockAddGauge(strategy);

        assertEq(address(factory.strategyGauges(strategy)), address(0));
        uint256 gaugesIds = factory.getGauges().length;
        assertEq(factory.gaugeIds(BaseV2Gauge(strategy)), 0);
        assertFalse(factory.activeGauges(BaseV2Gauge(strategy)));

        factory.createGauge(strategy, "");

        assertEq(address(factory.strategyGauges(strategy)), strategy);
        assertEq(address(factory.gauges(gaugesIds)), strategy);
        assertEq(factory.gaugeIds(BaseV2Gauge(strategy)), gaugesIds);
        assertTrue(factory.activeGauges(BaseV2Gauge(strategy)));
    }

    function testAlreadyCreated(address strategy) public {
        testCreateGauge(strategy);

        hevm.expectRevert(IBaseV2GaugeFactory.GaugeAlreadyExists.selector);
        factory.createGauge(strategy, "");
    }

    function testCreateGaugeNotOwner(address strategy) public {
        hevm.prank(address(0xCAF1));
        hevm.expectRevert(Unauthorized.selector);
        factory.createGauge(strategy, "");
    }

    function testRemoveGauge(BaseV2Gauge gauge) public {
        mockRemoveGauge(address(gauge));
        mockStrategy(address(gauge));

        testCreateGauge(address(gauge));

        assertEq(address(factory.gauges(factory.gaugeIds(gauge))), address(gauge));
        assertTrue(factory.activeGauges(gauge));
        assertEq(address(factory.strategyGauges(address(gauge))), address(gauge));

        factory.removeGauge(gauge);

        assertEq(address(factory.gauges(factory.gaugeIds(gauge))), address(0));
        assertFalse(factory.activeGauges(gauge));
        assertEq(address(factory.strategyGauges(address(gauge))), address(0));
    }

    function testAlreadyRemoved(BaseV2Gauge gauge) public {
        testRemoveGauge(gauge);

        hevm.expectRevert(IBaseV2GaugeFactory.InvalidGauge.selector);
        factory.removeGauge(gauge);
    }

    function testDoesntExist(BaseV2Gauge gauge) public {
        hevm.expectRevert(IBaseV2GaugeFactory.InvalidGauge.selector);
        factory.removeGauge(gauge);
    }

    function testRemoveInactive(BaseV2Gauge gauge) public {
        mockRemoveGauge(address(gauge));
        mockStrategy(address(gauge));

        testCreateGauge(address(gauge));
        factory.changeActiveGauge(gauge, false);

        hevm.expectRevert(IBaseV2GaugeFactory.InvalidGauge.selector);
        factory.removeGauge(gauge);

        factory.changeActiveGauge(gauge, true);
        factory.removeGauge(gauge);
    }

    function testRemoveGaugeNotOwner(BaseV2Gauge gauge) public {
        hevm.prank(address(0xCAF1));
        hevm.expectRevert(Unauthorized.selector);
        factory.removeGauge(gauge);
    }

    function testGetGauges(BaseV2Gauge gauge, BaseV2Gauge gauge2) public {
        hevm.assume(address(gauge) != address(gauge2));
        mockStrategy(address(gauge));
        mockStrategy(address(gauge2));

        assertEq(factory.getGauges().length, 0);

        testCreateGauge(address(gauge));
        assertEq(factory.getGauges().length, 1);
        testCreateGauge(address(gauge2));
        assertEq(factory.getGauges().length, 2);

        factory.removeGauge(gauge);
        assertEq(factory.getGauges().length, 2);
        factory.removeGauge(gauge2);
        assertEq(factory.getGauges().length, 2);
    }

    function testAddBribeToGauge(BaseV2Gauge gauge, address bribeToken) public {
        testCreateGauge(address(gauge));

        mockAddBribeToGauge(address(gauge));

        factory.addBribeToGauge(gauge, bribeToken);
    }

    function testAddBribeToGaugeOwner(BaseV2Gauge gauge, address bribeToken) public {
        mockBribesFactoryOwner(address(0xCAF1));

        hevm.expectRevert(IBaseV2GaugeFactory.InvalidGauge.selector);
        factory.addBribeToGauge(gauge, bribeToken);
    }

    function testAddBribeToGaugeBribesFactoryOwner(BaseV2Gauge gauge, address bribeToken) public {
        hevm.prank(address(0xCAF1));
        mockBribesFactoryOwner(address(0xCAF1));

        hevm.expectRevert(IBaseV2GaugeFactory.InvalidGauge.selector);
        factory.addBribeToGauge(gauge, bribeToken);
    }

    function testAddBribeToGaugeNotOwner(BaseV2Gauge gauge, address bribeToken) public {
        hevm.prank(address(0xCAF1));
        mockBribesFactoryOwner(address(0xCAF2));

        hevm.expectRevert(IBaseV2GaugeFactory.NotOwnerOrBribesFactoryOwner.selector);
        factory.addBribeToGauge(gauge, bribeToken);
    }

    function testRemoveBribeFromGauge(BaseV2Gauge gauge, address bribeToken) public {
        testCreateGauge(address(gauge));

        mockRemoveBribeFromGauge(address(gauge));

        factory.removeBribeFromGauge(gauge, bribeToken);
    }

    function testRemoveBribeFromGaugeOwner(BaseV2Gauge gauge, address bribeToken) public {
        mockBribesFactoryOwner(address(0xCAF1));

        hevm.expectRevert(IBaseV2GaugeFactory.InvalidGauge.selector);
        factory.removeBribeFromGauge(gauge, bribeToken);
    }

    function testRemoveBribeFromGaugeBribesFactoryOwner(BaseV2Gauge gauge, address bribeToken) public {
        hevm.prank(address(0xCAF1));
        mockBribesFactoryOwner(address(0xCAF1));

        hevm.expectRevert(IBaseV2GaugeFactory.InvalidGauge.selector);
        factory.removeBribeFromGauge(gauge, bribeToken);
    }

    function testRemoveBribeFromGaugeNotOwner(BaseV2Gauge gauge, address bribeToken) public {
        hevm.prank(address(0xCAF1));
        mockBribesFactoryOwner(address(0xCAF2));

        hevm.expectRevert(IBaseV2GaugeFactory.NotOwnerOrBribesFactoryOwner.selector);
        factory.removeBribeFromGauge(gauge, bribeToken);
    }
}
