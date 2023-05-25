// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {MockERC20Gauges} from "../erc-20/mocks/MockERC20Gauges.t.sol";
import {MockRewardsStream} from "../rewards/mocks/MockRewardsStream.sol";

import {bHermes} from "@hermes/bHermes.sol";
import {FlywheelBoosterGaugeWeight} from "@rewards/booster/FlywheelBoosterGaugeWeight.sol";
import {MultiRewardsDepot} from "@rewards/depots/MultiRewardsDepot.sol";
import {FlywheelCore, ERC20} from "@rewards/FlywheelCoreStrategy.sol";
import {FlywheelBribeRewards} from "@rewards/rewards/FlywheelBribeRewards.sol";
import {FlywheelGaugeRewards} from "@rewards/rewards/FlywheelGaugeRewards.sol";

import {UniswapV3Gauge} from "@gauges/UniswapV3Gauge.sol";

contract UniswapV3GaugeTest is DSTestPlus {
    MockERC20 public strategy;
    MockERC20 public rewardToken;
    MockERC20 public hermes;
    bHermes public bhermesToken;
    MockRewardsStream public rewardsStream;
    MultiRewardsDepot public depot;
    FlywheelBoosterGaugeWeight public booster;

    UniswapV3Gauge public gauge;

    uint256 constant WEEK = 604800;

    event Distribute(uint256 indexed amount, uint256 indexed epoch);

    event AddedBribeFlywheel(FlywheelCore indexed bribeFlywheel);

    event RemoveBribeFlywheel(FlywheelCore indexed bribeFlywheel);

    function setUp() public {
        hermes = new MockERC20("hermes", "HERMES", 18);

        rewardToken = new MockERC20("test token", "TKN", 18);
        strategy = new MockERC20("test strategy", "TKN", 18);

        rewardsStream = new MockRewardsStream(rewardToken, 100e18);
        rewardToken.mint(address(rewardsStream), 100e25);

        bhermesToken = new bHermes(hermes, address(this), 604800, 604800 / 7);
        bhermesToken.gaugeWeight().setMaxGauges(10);

        booster = new FlywheelBoosterGaugeWeight(bhermesToken.gaugeWeight());

        hevm.mockCall(address(this), abi.encodeWithSignature("rewardToken()"), abi.encode(address(rewardToken)));

        hevm.mockCall(
            address(this), abi.encodeWithSignature("bHermesBoostToken()"), abi.encode(bhermesToken.gaugeBoost())
        );

        gauge = new UniswapV3Gauge(
            FlywheelGaugeRewards(address(this)),
            address(this),
            address(this),
            10,
            address(this)
        );

        depot = gauge.multiRewardsDepot();

        bhermesToken.gaugeWeight().addGauge(address(gauge));
    }

    function testGetBribeFlywheelsEmpty() public view {
        require(gauge.getBribeFlywheels().length == 0);
    }

    function createFlywheel(MockERC20 token) private returns (FlywheelCore flywheel) {
        flywheel = new FlywheelCore(
            address(token),
            FlywheelBribeRewards(address(0)),
            booster,
            address(this)
        );
        FlywheelBribeRewards bribeRewards = new FlywheelBribeRewards(flywheel, 1000);
        flywheel.setFlywheelRewards(address(bribeRewards));
        flywheel.addStrategyForRewards(ERC20(address(gauge)));
    }

    function createFlywheel() private returns (FlywheelCore flywheel) {
        MockERC20 token = new MockERC20("test token", "TKN", 18);
        flywheel = createFlywheel(token);
    }

    function testAddBribeFlywheels() public {
        FlywheelCore flywheel = createFlywheel();

        hevm.expectEmit(true, true, true, true);
        emit AddedBribeFlywheel(flywheel);

        gauge.addBribeFlywheel(flywheel);

        require(gauge.getBribeFlywheels().length == 1);
        require(gauge.getBribeFlywheels()[0] == flywheel);
        require(gauge.isActive(flywheel));
        require(gauge.added(flywheel));
    }

    function testAddBribeFlywheelsAlreadyAdded() public {
        FlywheelCore flywheel = createFlywheel();

        hevm.expectEmit(true, true, true, true);
        emit AddedBribeFlywheel(flywheel);

        gauge.addBribeFlywheel(flywheel);

        require(gauge.getBribeFlywheels().length == 1);
        require(gauge.getBribeFlywheels()[0] == flywheel);
        require(gauge.isActive(flywheel));
        require(gauge.added(flywheel));

        hevm.expectRevert(abi.encodeWithSignature("FlywheelAlreadyAdded()"));
        gauge.addBribeFlywheel(flywheel);
    }

    function testAddBribeFlywheelsUnauthorized() public {
        FlywheelCore flywheel = createFlywheel();

        hevm.prank(address(1));
        hevm.expectRevert(Ownable.Unauthorized.selector);
        gauge.addBribeFlywheel(flywheel);
    }

    function testRemoveBribeFlywheels() public {
        FlywheelCore flywheel = createFlywheel();

        hevm.expectEmit(true, true, true, true);
        emit AddedBribeFlywheel(flywheel);

        gauge.addBribeFlywheel(flywheel);

        hevm.expectEmit(true, true, true, true);
        emit RemoveBribeFlywheel(flywheel);

        gauge.removeBribeFlywheel(flywheel);

        require(gauge.getBribeFlywheels().length == 1);
        require(gauge.getBribeFlywheels()[0] == flywheel);
        require(!gauge.isActive(flywheel));
        require(gauge.added(flywheel));
    }

    function testRemoveBribeFlywheelsNotActive() public {
        FlywheelCore flywheel = createFlywheel();

        hevm.expectRevert(abi.encodeWithSignature("FlywheelNotActive()"));
        gauge.removeBribeFlywheel(flywheel);
    }

    function testRemoveBribeFlywheelsAlreadyRemoved() public {
        FlywheelCore flywheel = createFlywheel();

        hevm.expectEmit(true, true, true, true);
        emit AddedBribeFlywheel(flywheel);

        gauge.addBribeFlywheel(flywheel);

        hevm.expectEmit(true, true, true, true);
        emit RemoveBribeFlywheel(flywheel);

        gauge.removeBribeFlywheel(flywheel);

        hevm.expectRevert(abi.encodeWithSignature("FlywheelNotActive()"));
        gauge.removeBribeFlywheel(flywheel);
    }

    function testRemoveBribeFlywheelsUnauthorized() public {
        FlywheelCore flywheel = createFlywheel();

        hevm.prank(address(1));
        hevm.expectRevert(Ownable.Unauthorized.selector);
        gauge.addBribeFlywheel(flywheel);
    }

    function setMinimumWidth() public {
        require(gauge.minimumWidth() == 10);
        gauge.setMinimumWidth(100);
        require(gauge.minimumWidth() == 100);
    }

    function testNewEpochFail() external {
        hevm.mockCall(address(this), abi.encodeWithSignature("getAccruedRewards()"), abi.encode(0));
        hevm.mockCall(address(this), abi.encodeWithSignature("createIncentiveFromGauge(uint256)", 0), "");

        uint256 epoch = gauge.epoch();
        gauge.newEpoch();
        assertEq(epoch, gauge.epoch());
    }

    function testNewEpochWorkThenFail() external {
        hevm.warp(WEEK); // skip to cycle 1

        hevm.mockCall(address(this), abi.encodeWithSignature("getAccruedRewards()"), abi.encode(0));
        hevm.mockCall(address(this), abi.encodeWithSignature("createIncentiveFromGauge(uint256)", 0), "");

        hevm.expectEmit(true, true, true, true);
        emit Distribute(0, WEEK);

        gauge.newEpoch();
        uint256 epoch = gauge.epoch();
        gauge.newEpoch();
        assertEq(epoch, gauge.epoch());
    }

    function testNewEpochEmpty() external {
        hevm.warp(WEEK); // skip to cycle 1

        hevm.mockCall(address(this), abi.encodeWithSignature("getAccruedRewards()"), abi.encode(0));
        hevm.mockCall(address(this), abi.encodeWithSignature("createIncentiveFromGauge(uint256)", 0), "");

        hevm.expectEmit(true, true, true, true);
        emit Distribute(0, WEEK);

        gauge.newEpoch();
    }

    function testNewEpoch() external {
        hevm.warp(WEEK); // skip to cycle 1

        hevm.mockCall(address(this), abi.encodeWithSignature("getAccruedRewards()"), abi.encode(100e18));
        hevm.mockCall(address(this), abi.encodeWithSignature("createIncentiveFromGauge(uint256)", 100e18), "");

        hevm.expectEmit(true, true, true, true);
        emit Distribute(100e18, WEEK);

        gauge.newEpoch();
    }

    function testNewEpoch(uint256 amount) external {
        hevm.warp(WEEK); // skip to cycle 1

        hevm.mockCall(address(this), abi.encodeWithSignature("getAccruedRewards()"), abi.encode(amount));
        hevm.mockCall(address(this), abi.encodeWithSignature("createIncentiveFromGauge(uint256)", amount), "");

        hevm.expectEmit(true, true, true, true);
        emit Distribute(amount, WEEK);

        gauge.newEpoch();
    }

    function testNewEpochTwice(uint256 amount) external {
        hevm.warp(WEEK); // skip to cycle 1

        hevm.mockCall(address(this), abi.encodeWithSignature("getAccruedRewards()"), abi.encode(amount));
        hevm.mockCall(address(this), abi.encodeWithSignature("createIncentiveFromGauge(uint256)", amount), "");

        hevm.expectEmit(true, true, true, true);
        emit Distribute(amount, WEEK);

        gauge.newEpoch();

        hevm.warp(2 * WEEK); // skip to cycle 2

        hevm.expectEmit(true, true, true, true);
        emit Distribute(amount, 2 * WEEK);

        gauge.newEpoch();
    }

    function testNewEpochTwiceSecondHasNothing(uint256 amount) external {
        hevm.warp(WEEK); // skip to cycle 1

        hevm.mockCall(address(this), abi.encodeWithSignature("getAccruedRewards()"), abi.encode(amount));
        hevm.mockCall(address(this), abi.encodeWithSignature("createIncentiveFromGauge(uint256)", amount), "");

        hevm.expectEmit(true, true, true, true);
        emit Distribute(amount, WEEK);

        gauge.newEpoch();

        hevm.warp(2 * WEEK); // skip to cycle 2

        hevm.mockCall(address(this), abi.encodeWithSignature("getAccruedRewards()"), abi.encode(0));
        hevm.mockCall(address(this), abi.encodeWithSignature("createIncentiveFromGauge(uint256)", 0), "");

        hevm.expectEmit(true, true, true, true);
        emit Distribute(0, 2 * WEEK);

        gauge.newEpoch();
    }

    function testAccrueBribesBeforeAddBribeFlyWheel() external {
        MockERC20 token = new MockERC20("test token", "TKN", 18);
        FlywheelCore flywheel = createFlywheel(token);
        FlywheelBribeRewards bribeRewards = FlywheelBribeRewards(address(flywheel.flywheelRewards()));

        token.mint(address(depot), 100 ether);

        gauge.accrueBribes(address(this));

        require(token.balanceOf(address(bribeRewards)) == 0 ether);

        // Note: rewards can still be accrued directly through the flywheel
    }

    function testAccrueBribesBeforeAddBribeFlyWheel(uint256 amount) external {
        MockERC20 token = new MockERC20("test token", "TKN", 18);
        FlywheelCore flywheel = createFlywheel(token);
        FlywheelBribeRewards bribeRewards = FlywheelBribeRewards(address(flywheel.flywheelRewards()));
        amount %= type(uint128).max;

        token.mint(address(depot), amount);

        gauge.accrueBribes(address(this));

        require(token.balanceOf(address(bribeRewards)) == 0);

        // Note: rewards can still be accrued directly through the flywheel
    }

    function testAccrueBribes() external {
        MockERC20 token = new MockERC20("test token", "TKN", 18);
        FlywheelCore flywheel = createFlywheel(token);
        FlywheelBribeRewards bribeRewards = FlywheelBribeRewards(address(flywheel.flywheelRewards()));

        token.mint(address(depot), 100 ether);

        hevm.expectEmit(true, true, true, true);
        emit AddedBribeFlywheel(flywheel);

        gauge.addBribeFlywheel(flywheel);

        gauge.accrueBribes(address(this));

        require(token.balanceOf(address(bribeRewards)) == 100 ether);
    }

    function testAccrueBribes(uint256 amount) external {
        MockERC20 token = new MockERC20("test token", "TKN", 18);
        FlywheelCore flywheel = createFlywheel(token);
        FlywheelBribeRewards bribeRewards = FlywheelBribeRewards(address(flywheel.flywheelRewards()));
        amount %= type(uint128).max;

        token.mint(address(depot), amount);

        hevm.expectEmit(true, true, true, true);
        emit AddedBribeFlywheel(flywheel);

        gauge.addBribeFlywheel(flywheel);

        gauge.accrueBribes(address(this));

        require(token.balanceOf(address(bribeRewards)) == amount);
    }
}
