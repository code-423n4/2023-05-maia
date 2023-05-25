// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";

import "../mocks/MockBaseV2GaugeManager.sol";

error Unauthorized();
error NotAdmin();

contract BaseV2GaugeManagerTest is DSTestPlus {
    address _bHermes = address(0xCAFE);
    address _admin = address(0xBCAA);

    address gaugeWeight = address(0xCAFD);
    address gaugeBoost = address(0xCAFC);

    MockBaseV2GaugeManager manager;

    function mockBHermes() public {
        hevm.mockCall(_bHermes, abi.encodeWithSignature("gaugeWeight()"), abi.encode(gaugeWeight));
        hevm.mockCall(_bHermes, abi.encodeWithSignature("gaugeBoost()"), abi.encode(gaugeBoost));
    }

    function setUp() public {
        mockBHermes();
        manager = new MockBaseV2GaugeManager(
            bHermes(_bHermes),
            address(this),
            _admin
        );
    }

    function mockNewEpoch(address gaugeFactory) public {
        hevm.mockCall(gaugeFactory, abi.encodeWithSignature("newEpoch()"), "");
    }

    function mockBHermesAddGauge() public {
        hevm.mockCall(gaugeWeight, abi.encodeWithSignature("addGauge(address)"), "");
        hevm.mockCall(gaugeBoost, abi.encodeWithSignature("addGauge(address)"), "");
    }

    function mockBHermesRemoveGauge() public {
        hevm.mockCall(gaugeWeight, abi.encodeWithSignature("removeGauge(address)"), "");
        hevm.mockCall(gaugeBoost, abi.encodeWithSignature("removeGauge(address)"), "");
    }

    function mockBHermesChangeOwner() public {
        hevm.mockCall(gaugeWeight, abi.encodeWithSignature("transferOwnership(address)"), "");
        hevm.mockCall(gaugeBoost, abi.encodeWithSignature("transferOwnership(address)"), "");
    }

    function testNewEpoch(uint80 gaugeFactory) public {
        address gaugeFactory1 = address(uint160(gaugeFactory));
        address gaugeFactory2 = address(uint160(gaugeFactory) + 1);

        testAddGaugeFactory(BaseV2GaugeFactory(gaugeFactory1));

        manager.changeActiveGaugeFactory(BaseV2GaugeFactory(gaugeFactory1), false);

        manager.newEpoch();

        testAddGaugeFactory(BaseV2GaugeFactory(gaugeFactory2));

        mockNewEpoch(gaugeFactory2);

        hevm.expectCall(gaugeFactory2, abi.encodeWithSignature("newEpoch()"));
        manager.newEpoch();
    }

    function testNewEpochRangeSetup(uint80 gaugeFactory) public returns (address, address) {
        address gaugeFactory1 = address(uint160(gaugeFactory));
        address gaugeFactory2 = address(uint160(gaugeFactory) + 1);
        address gaugeFactory3 = address(uint160(gaugeFactory) + 2);
        address gaugeFactory4 = address(uint160(gaugeFactory) + 3);

        testAddGaugeFactory(BaseV2GaugeFactory(gaugeFactory1));
        testAddGaugeFactory(BaseV2GaugeFactory(gaugeFactory2));

        manager.changeActiveGaugeFactory(BaseV2GaugeFactory(gaugeFactory1), false);
        manager.changeActiveGaugeFactory(BaseV2GaugeFactory(gaugeFactory2), false);

        manager.newEpoch(0, 2);
        manager.newEpoch(0, 10);
        manager.newEpoch(1, 10);

        testAddGaugeFactory(BaseV2GaugeFactory(gaugeFactory3));
        testAddGaugeFactory(BaseV2GaugeFactory(gaugeFactory4));

        manager.newEpoch(0, 2);
        manager.newEpoch(1, 2);

        mockNewEpoch(gaugeFactory3);
        mockNewEpoch(gaugeFactory4);

        return (gaugeFactory3, gaugeFactory4);
    }

    function testNewEpochRangeBoth(uint80 gaugeFactory) public {
        (address gaugeFactory3, address gaugeFactory4) = testNewEpochRangeSetup(gaugeFactory);

        hevm.expectCall(gaugeFactory3, abi.encodeWithSignature("newEpoch()"));
        hevm.expectCall(gaugeFactory4, abi.encodeWithSignature("newEpoch()"));
        manager.newEpoch(0, 4);
    }

    function testNewEpochRangeSingle(uint80 gaugeFactory) public {
        (address gaugeFactory3, address gaugeFactory4) = testNewEpochRangeSetup(gaugeFactory);

        manager.changeActiveGaugeFactory(BaseV2GaugeFactory(gaugeFactory3), false);
        hevm.expectCall(gaugeFactory4, abi.encodeWithSignature("newEpoch()"));
        manager.newEpoch(0, 4);
    }

    function testNewEpochRangeOver(uint80 gaugeFactory) public {
        (address gaugeFactory3, address gaugeFactory4) = testNewEpochRangeSetup(gaugeFactory);

        hevm.expectCall(gaugeFactory3, abi.encodeWithSignature("newEpoch()"));
        hevm.expectCall(gaugeFactory4, abi.encodeWithSignature("newEpoch()"));
        manager.newEpoch(0, 10);
    }

    function testNewEpochRangeUnder(uint80 gaugeFactory) public {
        (address gaugeFactory3, address gaugeFactory4) = testNewEpochRangeSetup(gaugeFactory);

        hevm.expectCall(gaugeFactory3, abi.encodeWithSignature("newEpoch()"));
        hevm.expectCall(gaugeFactory4, abi.encodeWithSignature("newEpoch()"));
        manager.newEpoch(2, 4);
    }

    function testNewEpochRangeOverUnder(uint80 gaugeFactory) public {
        (address gaugeFactory3, address gaugeFactory4) = testNewEpochRangeSetup(gaugeFactory);

        hevm.expectCall(gaugeFactory3, abi.encodeWithSignature("newEpoch()"));
        hevm.expectCall(gaugeFactory4, abi.encodeWithSignature("newEpoch()"));
        manager.newEpoch(2, 10);
    }

    // TODO - check failing test on mocked call
    // function testAddGauge(address gauge) public {
    //     testAddGaugeFactory(BaseV2GaugeFactory(gauge));
    //     assertTrue(manager.activeGaugeFactories(BaseV2GaugeFactory(gauge)));
    //     mockBHermesAddGauge();
    //     hevm.prank(gauge);
    //     manager.addGauge(gauge);
    // }

    function testAddGaugeNotGaugeFactory(address gauge) public {
        testAddGaugeFactory(BaseV2GaugeFactory(gauge));
        mockBHermesAddGauge();
        assertFalse(manager.activeGaugeFactories(BaseV2GaugeFactory(address(this))));
        hevm.expectRevert(IBaseV2GaugeManager.NotActiveGaugeFactory.selector);
        manager.addGauge(gauge);
    }

    function testAddGaugeNotExists(address gauge) public {
        hevm.assume(gauge != address(this));
        mockBHermesAddGauge();
        assertFalse(manager.activeGaugeFactories(BaseV2GaugeFactory(gauge)));
        hevm.expectRevert(IBaseV2GaugeManager.NotActiveGaugeFactory.selector);
        hevm.prank(gauge);
        manager.addGauge(gauge);
    }

    function testRemoveGauge(address gauge) public {
        hevm.assume(gauge != address(this));
        testAddGaugeFactory(BaseV2GaugeFactory(gauge));
        assertTrue(manager.activeGaugeFactories(BaseV2GaugeFactory(gauge)));
        mockBHermesRemoveGauge();
        hevm.prank(gauge);
        manager.removeGauge(gauge);
    }

    function testRemoveGaugeNotGaugeFactory(address gauge) public {
        testAddGaugeFactory(BaseV2GaugeFactory(gauge));
        mockBHermesAddGauge();
        assertFalse(manager.activeGaugeFactories(BaseV2GaugeFactory(address(this))));
        hevm.expectRevert(IBaseV2GaugeManager.NotActiveGaugeFactory.selector);
        manager.removeGauge(gauge);
    }

    function testRemoveGaugeNotExists(address gauge) public {
        hevm.assume(gauge != address(this));
        mockBHermesAddGauge();
        assertFalse(manager.activeGaugeFactories(BaseV2GaugeFactory(gauge)));
        hevm.expectRevert(IBaseV2GaugeManager.NotActiveGaugeFactory.selector);
        hevm.prank(gauge);
        manager.removeGauge(gauge);
    }

    function testGetGaugeFactories(BaseV2GaugeFactory gaugeFactory, BaseV2GaugeFactory gaugeFactory2) public {
        hevm.assume(address(gaugeFactory) != address(gaugeFactory2));

        assertEq(manager.getGaugeFactories().length, 0);

        testAddGaugeFactory(gaugeFactory);
        assertEq(manager.getGaugeFactories().length, 1);
        testAddGaugeFactory(gaugeFactory2);
        assertEq(manager.getGaugeFactories().length, 2);
        manager.removeGaugeFactory(gaugeFactory);

        assertEq(manager.getGaugeFactories().length, 2);
        manager.removeGaugeFactory(gaugeFactory2);
        assertEq(manager.getGaugeFactories().length, 2);
    }

    function testAddGaugeFactory(BaseV2GaugeFactory gaugeFactory) public {
        assertEq(manager.gaugeFactoryIds(gaugeFactory), 0);
        uint256 gaugeFactoryIds = manager.getGaugeFactories().length;
        assertFalse(manager.activeGaugeFactories(gaugeFactory));

        manager.addGaugeFactory(gaugeFactory);

        assertEq(manager.gaugeFactoryIds(gaugeFactory), gaugeFactoryIds);
        assertEq(address(manager.gaugeFactories(gaugeFactoryIds)), address(gaugeFactory));
        assertTrue(manager.activeGaugeFactories(gaugeFactory));
    }

    function testAddGaugeFactoryAlreadyExists(BaseV2GaugeFactory gaugeFactory) public {
        testAddGaugeFactory(gaugeFactory);

        hevm.expectRevert(IBaseV2GaugeManager.GaugeFactoryAlreadyExists.selector);
        manager.addGaugeFactory(gaugeFactory);
    }

    function testAddGaugeFactoryEvent(BaseV2GaugeFactory gaugeFactory) public {
        hevm.expectEmit(true, true, true, true);
        emit AddedGaugeFactory(address(gaugeFactory));
        manager.addGaugeFactory(gaugeFactory);
    }

    function testAddGaugeFactoryNotOwner(address gaugeFactory) public {
        hevm.prank(address(0xCAF1));
        hevm.expectRevert(Unauthorized.selector);
        manager.addGaugeFactory(BaseV2GaugeFactory(gaugeFactory));
    }

    function testRemoveGaugeFactory(BaseV2GaugeFactory gaugeFactory) public {
        uint256 gaugeFactoryIds = manager.getGaugeFactories().length;
        testAddGaugeFactory(gaugeFactory);

        assertEq(manager.gaugeFactoryIds(gaugeFactory), gaugeFactoryIds);
        assertEq(address(manager.gaugeFactories(gaugeFactoryIds)), address(gaugeFactory));
        assertTrue(manager.activeGaugeFactories(gaugeFactory));

        manager.removeGaugeFactory(gaugeFactory);

        assertEq(manager.gaugeFactoryIds(gaugeFactory), 0);
        assertEq(address(manager.gaugeFactories(manager.gaugeFactoryIds(gaugeFactory))), address(0));
        assertFalse(manager.activeGaugeFactories(gaugeFactory));
    }

    function testRemoveGaugeFactoryEvent(BaseV2GaugeFactory gaugeFactory) public {
        testAddGaugeFactory(gaugeFactory);
        hevm.expectEmit(true, true, true, true);
        emit RemovedGaugeFactory(address(gaugeFactory));
        manager.removeGaugeFactory(gaugeFactory);
    }

    function testRemoveGaugeFactoryNotOwner(address gaugeFactory) public {
        hevm.prank(address(0xCAF1));
        hevm.expectRevert(Unauthorized.selector);
        manager.removeGaugeFactory(BaseV2GaugeFactory(gaugeFactory));
    }

    function testChangebHermesGaugeOwner(address newOwner) public {
        mockBHermesChangeOwner();
        hevm.prank(_admin);
        manager.changebHermesGaugeOwner(newOwner);
    }

    function testChangebHermesGaugeOwnerEvent(address newOwner) public {
        mockBHermesChangeOwner();

        hevm.prank(_admin);
        hevm.expectEmit(true, true, true, true);
        emit ChangedbHermesGaugeOwner(newOwner);
        manager.changebHermesGaugeOwner(newOwner);
    }

    function testChangebHermesGaugeOwnerNotAdmin(address newOwner) public {
        hevm.expectRevert(NotAdmin.selector);
        manager.changebHermesGaugeOwner(newOwner);
    }

    function testChangeAdmin(address newAdmin) public {
        assertEq(manager.admin(), address(_admin));
        hevm.prank(_admin);
        manager.changeAdmin(newAdmin);
        assertEq(manager.admin(), newAdmin);
    }

    function testChangeAdminNotAdmin(address newAdmin) public {
        assertEq(manager.admin(), address(_admin));
        hevm.expectRevert(NotAdmin.selector);
        manager.changeAdmin(newAdmin);
    }

    function testChangeAdminEvent(address newAdmin) public {
        hevm.prank(_admin);
        hevm.expectEmit(true, true, true, true);
        emit ChangedAdmin(newAdmin);
        manager.changeAdmin(newAdmin);
    }

    /// @notice Emitted when a new gauge factory is added.
    event AddedGaugeFactory(address gaugeFactory);

    /// @notice Emitted when a gauge factory is removed.
    event RemovedGaugeFactory(address gaugeFactory);

    /// @notice Emitted when changing bHermes GaugeWeight and GaugeWeight owner.
    event ChangedbHermesGaugeOwner(address newOwner);

    /// @notice Emitted when changing admin.
    event ChangedAdmin(address newAdmin);
}
