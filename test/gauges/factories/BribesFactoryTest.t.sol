// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";

import { MockERC20 } from "../mocks/MockERC20.sol";
import "../mocks/MockBaseV2GaugeManager.sol";

import "../mocks/MockBribesFactory.sol";

error Unauthorized();

contract BribesFactoryTest is DSTestPlus {

    address gaugeManager = address(0xCAFE);
    address flywheelGaugeWeightBooster = address(0xBCAA);
    uint256 rewardsCycleLength = 10;

    address _bHermes = address(0xCAFA);
    address _admin = address(0xCAFB);

    MockBribesFactory factory;
    MockBaseV2GaugeManager manager;
    ERC20 bribeToken;
    ERC20 bribeToken2;

    function mockBHermes() public {
        hevm.mockCall(_bHermes,
                    abi.encodeWithSignature("gaugeWeight()"),
                    abi.encode(address(0xCAFC))
                    );
        hevm.mockCall(_bHermes,
                    abi.encodeWithSignature("gaugeBoost()"),
                    abi.encode(address(0xCAFD))
                    );
    }

    function setUp() public {
        mockBHermes();
        manager = new MockBaseV2GaugeManager(
            bHermes(_bHermes),
            address(this),
            _admin
        );
        factory = new MockBribesFactory(
            manager,
            FlywheelBoosterGaugeWeight(flywheelGaugeWeightBooster),
            rewardsCycleLength,
            address(this)
        );
        bribeToken = new MockERC20("Bribe Token", "BRIBE", 18);
        bribeToken2 = new MockERC20("Bribe Token2", "BRIBE2", 18);
    }

    function testConstructor() public {
        assertEq(address(factory.gaugeManager()), address(manager));
        // assertEq(address(factory.flywheelGaugeWeightBooster()), flywheelGaugeWeightBooster);
        assertEq(factory.rewardsCycleLength(), rewardsCycleLength);
        assertEq(factory.owner(), address(this));
    }

    function testCreateBribeFlywheel() public {
        factory.createBribeFlywheel(address(bribeToken));

        FlywheelCore flywheel = factory.flywheelTokens(address(bribeToken));

        assertEq(flywheel.rewardToken(), address(bribeToken));
        assertEq(address(flywheel.flywheelBooster()), flywheelGaugeWeightBooster);
        assertEq(flywheel.owner(), address(factory));
        assertTrue(factory.activeBribeFlywheels(flywheel));
        assertFalse(address(flywheel.flywheelRewards()) == address(0));

        flywheel = factory.bribeFlywheels(0);

        assertEq(flywheel.rewardToken(), address(bribeToken));
        assertEq(address(flywheel.flywheelBooster()), flywheelGaugeWeightBooster);
        assertEq(flywheel.owner(), address(factory));
        assertTrue(factory.activeBribeFlywheels(flywheel));
        assertFalse(address(flywheel.flywheelRewards()) == address(0));
    }

    function testGetBribeFlywheels() public {
        assertEq(factory.getBribeFlywheels().length, 0);
        factory.createBribeFlywheel(address(bribeToken));
        assertEq(factory.getBribeFlywheels().length, 1);
        factory.createBribeFlywheel(address(bribeToken2));
        assertEq(factory.getBribeFlywheels().length, 2);
    }

    function testCreateBribeFlywheelEvent() public {
        hevm.expectEmit(false, false, false, false);
        emit BribeFlywheelCreated(address(bribeToken), FlywheelCore(address(0)));
        factory.createBribeFlywheel(address(bribeToken));
    }

    function testCreateBribeFlywheelIds() public {
        factory.createBribeFlywheel(address(bribeToken));
        factory.createBribeFlywheel(address(bribeToken2));

        FlywheelCore flywheel = factory.bribeFlywheels(0);
        FlywheelCore flywheel2 = factory.bribeFlywheels(1);
        
        assertEq(factory.bribeFlywheelIds(flywheel), 0);
        assertEq(factory.bribeFlywheelIds(flywheel2), 1);
    }

    function testCreateBribeFlywheelAlreadyExists() public {
        factory.createBribeFlywheel(address(bribeToken));
        hevm.expectRevert(IBribesFactory.BribeFlywheelAlreadyExists.selector);
        factory.createBribeFlywheel(address(bribeToken));
    }

    function testAddGaugetoFlywheel(address gauge, BaseV2GaugeFactory gaugeFactory) public {
        hevm.assume(address(gaugeFactory) != address(0));

        manager.addGaugeFactory(gaugeFactory);
        factory.createBribeFlywheel(address(bribeToken));

        factory.bribeFlywheels(0);

        hevm.prank(address(gaugeFactory));
        factory.addGaugetoFlywheel(gauge, address(bribeToken));
    }

    function testAddGaugetoFlywheelNotExists(address gauge, BaseV2GaugeFactory gaugeFactory) public {
        hevm.assume(address(gaugeFactory) != address(0));

        manager.addGaugeFactory(gaugeFactory);

        hevm.prank(address(gaugeFactory));
        hevm.expectEmit(false, false, false, false);
        emit BribeFlywheelCreated(address(bribeToken), FlywheelCore(address(0)));
        factory.addGaugetoFlywheel(gauge, address(bribeToken));
    }

    function testAddGaugetoFlywheelUnauthorized(address gauge, BaseV2GaugeFactory gaugeFactory) public {
        hevm.assume(address(gaugeFactory) != address(0));

        hevm.prank(address(gaugeFactory));
        hevm.expectRevert(Unauthorized.selector);
        factory.addGaugetoFlywheel(gauge, address(bribeToken));
    }

    function testAddGaugetoFlywheelUnauthorizedNotFactory(address gauge, BaseV2GaugeFactory gaugeFactory) public {
        hevm.assume(address(gaugeFactory) != address(0));

        manager.addGaugeFactory(gaugeFactory);

        hevm.expectRevert(Unauthorized.selector);
        factory.addGaugetoFlywheel(gauge, address(bribeToken));
    }

    event BribeFlywheelCreated(address indexed bribeToken, FlywheelCore flywheel);
}