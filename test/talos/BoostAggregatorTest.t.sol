// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {Ownable} from "solady/auth/Ownable.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";

import {UniswapV3GaugeFactory} from "@gauges/factories/UniswapV3GaugeFactory.sol";

import {UniswapV3GaugeFactory} from "@gauges/factories/UniswapV3GaugeFactory.sol";

import {BoostAggregator, IBoostAggregator} from "@talos/boost-aggregator/BoostAggregator.sol";
import {TalosStrategyStaked} from "@talos/TalosStrategyStaked.sol";
import {TalosBaseStrategy} from "@talos/base/TalosBaseStrategy.sol";
import {PoolVariables, PoolActions} from "@talos/libraries/PoolActions.sol";

import {FlywheelCoreInstant, IFlywheelBooster} from "@rewards/FlywheelCoreInstant.sol";
import {FlywheelInstantRewards} from "@rewards/rewards/FlywheelInstantRewards.sol";
import {IFlywheelRewards} from "@rewards/interfaces/IFlywheelRewards.sol";

import {
    IUniswapV3Pool,
    UniswapV3Staker,
    IUniswapV3Staker,
    IncentiveTime,
    IncentiveId,
    bHermesBoost
} from "@v3-staker/UniswapV3Staker.sol";

import {TalosTestor} from "./TalosTestor.t.sol";

contract BoostAggregatorTest is TalosTestor {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for uint160;
    using FixedPointMathLib for uint128;
    using SafeCastLib for uint256;
    using SafeCastLib for int256;
    using PoolVariables for IUniswapV3Pool;
    using PoolActions for IUniswapV3Pool;
    using SafeTransferLib for ERC20;

    //////////////////////////////////////////////////////////////////
    //                          VARIABLES
    //////////////////////////////////////////////////////////////////

    IUniswapV3Staker uniswapV3Staker;
    UniswapV3Staker uniswapV3StakerContract;

    IUniswapV3Staker.IncentiveKey key;
    bytes32 incentiveId;

    FlywheelCoreInstant flywheel;
    FlywheelInstantRewards rewards;

    BoostAggregator boostAggregator;

    bHermesBoost gaugeBoost;

    // //////////////////////////////////////////////////////////////////
    // //                          SET UP
    // //////////////////////////////////////////////////////////////////

    function setUp() public {
        init();
    }

    function initializeTalos() internal override {
        gaugeBoost = new bHermesBoost(address(this));
        gaugeBoost.addGauge(address(this));

        uniswapV3StakerContract = new UniswapV3Staker(
            uniswapV3Factory,
            nonfungiblePositionManager,
            UniswapV3GaugeFactory(address(this)),
            gaugeBoost,
            31536000,
            address(this),
            address(rewardToken)
        );
        uniswapV3Staker = IUniswapV3Staker(address(uniswapV3StakerContract));

        hevm.mockCall(
            address(this), abi.encodeWithSignature("strategyGauges(address)", pool), abi.encode(address(this))
        );
        hevm.mockCall(address(this), abi.encodeWithSignature("multiRewardsDepot()"), abi.encode(address(this)));
        hevm.mockCall(address(this), abi.encodeWithSignature("minimumWidth()"), abi.encode(10));
        uniswapV3StakerContract.updateGauges(pool);

        uniswapV3StakerContract.gauges(pool);
        uniswapV3StakerContract.gaugePool(address(this));

        rewardToken.approve(address(uniswapV3Staker), type(uint256).max);
        rewardToken.mint(address(this), 6e25);

        hevm.warp(10000000);
        key = IUniswapV3Staker.IncentiveKey({startTime: IncentiveTime.computeEnd(block.timestamp), pool: pool});
        uniswapV3StakerContract.createIncentiveFromGauge(1e25);
        uniswapV3StakerContract.createIncentive(
            IUniswapV3Staker.IncentiveKey({startTime: IncentiveTime.computeEnd(block.timestamp + 1 weeks), pool: pool}),
            1e25
        );
        uniswapV3StakerContract.createIncentive(
            IUniswapV3Staker.IncentiveKey({startTime: IncentiveTime.computeEnd(block.timestamp + 2 weeks), pool: pool}),
            1e25
        );
        uniswapV3StakerContract.createIncentive(
            IUniswapV3Staker.IncentiveKey({startTime: IncentiveTime.computeEnd(block.timestamp + 3 weeks), pool: pool}),
            1e25
        );
        uniswapV3StakerContract.createIncentive(
            IUniswapV3Staker.IncentiveKey({startTime: IncentiveTime.computeEnd(block.timestamp + 4 weeks), pool: pool}),
            1e25
        );
        uniswapV3StakerContract.createIncentive(
            IUniswapV3Staker.IncentiveKey({startTime: IncentiveTime.computeEnd(block.timestamp + 5 weeks), pool: pool}),
            1e25
        );

        hevm.warp(IncentiveTime.computeEnd(block.timestamp));

        flywheel = new FlywheelCoreInstant(
            address(rewardToken),
            IFlywheelRewards(address(0)),
            IFlywheelBooster(address(0)),
            address(this)
        );
        rewards = new FlywheelInstantRewards(flywheel);
        flywheel.setFlywheelRewards(address(rewards));

        boostAggregator = new BoostAggregator(uniswapV3StakerContract, rewardToken, address(this));

        hevm.mockCall(
            address(this), abi.encodeWithSignature("attachUser(address)", address(boostAggregator)), abi.encode("")
        );
        hevm.mockCall(
            address(this), abi.encodeWithSignature("detachUser(address)", address(boostAggregator)), abi.encode("")
        );

        talosBaseStrategy = new TalosStrategyStaked(
            pool,
            strategyOptimizer,
            boostAggregator,
            address(this),
            flywheel,
            address(this)
        );

        flywheel.addStrategyForRewards(talosBaseStrategy);

        boostAggregator.addWhitelistedAddress(address(talosBaseStrategy));
    }

    /*//////////////////////////////////////////////////////////////
                        SET OWN REWARDS DEPOT
    //////////////////////////////////////////////////////////////*/

    // Set own rewards depot test, this call should never fail
    function test_setOwnRewardsDepot(address user, address rewardsDepot) public {
        hevm.prank(user);
        boostAggregator.setOwnRewardsDepot(rewardsDepot);
        assertEq(boostAggregator.userToRewardsDepot(user), rewardsDepot);
    }

    /*//////////////////////////////////////////////////////////////
                        ADD/REMOVE WHITELISTED ADDRESS
    //////////////////////////////////////////////////////////////*/

    // Add whitelisted address test, this call should never fail if called by owner
    function test_addWhitelistedAddress(address user) public {
        boostAggregator.addWhitelistedAddress(user);
        assertTrue(boostAggregator.whitelistedAddresses(user));
    }

    // Add whitelisted address fail test, this call should fail if called by non-owner
    function test_fail_addWhitelistedAddress(address user) public {
        if (user != address(this)) hevm.expectRevert(Ownable.Unauthorized.selector);
        hevm.prank(user);
        boostAggregator.addWhitelistedAddress(user);
    }

    // Remove whitelisted address test, this call should never fail if called by owner
    function test_removeWhitelistedAddress(address user) public {
        boostAggregator.removeWhitelistedAddress(user);
        assertFalse(boostAggregator.whitelistedAddresses(user));
    }

    // Remove whitelisted address fail test, this call should fail if called by non-owner
    function test_fail_removeWhitelistedAddress(address user) public {
        if (user != address(this)) hevm.expectRevert(Ownable.Unauthorized.selector);
        hevm.prank(user);
        boostAggregator.removeWhitelistedAddress(user);
    }

    // Add then remove whitelisted address test, this call should never fail if called by owner
    function test_add_then_removeWhitelistedAddress(address user) public {
        test_addWhitelistedAddress(user);
        test_removeWhitelistedAddress(user);
    }

    /*//////////////////////////////////////////////////////////////
                        SET PROTOCOL FEE
    //////////////////////////////////////////////////////////////*/

    // Set protocol fee test, protocol fee needs to be less than 10000
    function test_setProtocolFee(uint256 fee) public {
        fee = fee % 10000;
        boostAggregator.setProtocolFee(fee);
        assertEq(boostAggregator.protocolFee(), fee);
    }

    // Set protocol fee fail test, protocol fee is greater than 10000
    function test_fail_setProtocolFee(uint256 fee) public {
        if (fee <= 10000) fee = 10001;
        hevm.expectRevert(IBoostAggregator.FeeTooHigh.selector);
        boostAggregator.setProtocolFee(fee);
    }

    // Set protocol fee fail test, not called by owner
    function test_fail_setProtocolFee_notOwner(uint256 fee) public {
        if (msg.sender != address(this)) hevm.expectRevert(Ownable.Unauthorized.selector);
        hevm.prank(msg.sender);
        boostAggregator.setProtocolFee(fee);
    }

    /*//////////////////////////////////////////////////////////////
                        WITHDRAW PROTOCOL FEES
    //////////////////////////////////////////////////////////////*/

    // Withdraw protocol fees test, this call should never fail if called by owner
    function test_withdrawProtocolFees(address receiver) public {
        uint256 balance = rewardToken.balanceOf(receiver);
        uint256 fees = boostAggregator.protocolRewards();
        boostAggregator.withdrawProtocolFees(receiver);
        assertEq(rewardToken.balanceOf(receiver), balance + fees);
        assertEq(boostAggregator.protocolRewards(), 0);
    }

    // Withdraw protocol fees fail test, not called by owner
    function test_fail_withdrawProtocolFees(address user, address receiver) public {
        if (user != address(this)) hevm.expectRevert(Ownable.Unauthorized.selector);
        hevm.prank(user);
        boostAggregator.withdrawProtocolFees(receiver);
    }

    /*//////////////////////////////////////////////////////////////
                        WITHDRAW GAUGE BOOST
    //////////////////////////////////////////////////////////////*/

    function checkBoostBalance(address user, uint256 boostAmount) public {
        assertEq(gaugeBoost.balanceOf(address(user)), boostAmount);
    }

    function depositBoost(uint256 boostAmount) public {
        uint256 balance = gaugeBoost.balanceOf(address(boostAggregator));
        gaugeBoost.mint(address(boostAggregator), boostAmount);
        checkBoostBalance(address(boostAggregator), balance + boostAmount);
    }

    // Withdraw all gauge boost test, this call should never fail if called by owner
    function test_withdrawAllGaugeBoost(address receiver, uint256 boostAmount) public {
        depositBoost(boostAmount);
        boostAggregator.withdrawAllGaugeBoost(receiver);

        checkBoostBalance(receiver, boostAmount);
        checkBoostBalance(address(boostAggregator), 0);
    }

    // Withdraw all gauge boost fail test, not called by owner
    function test_fail_withdrawAllGaugeBoost(address user, address receiver, uint256 boostAmount) public {
        depositBoost(boostAmount);
        if (user != address(this)) hevm.expectRevert(Ownable.Unauthorized.selector);
        hevm.prank(user);
        boostAggregator.withdrawAllGaugeBoost(receiver);
    }

    function test_withdrawGaugeBoost(address receiver, uint256 boostAmount, uint256 amount) public {
        boostAmount %= type(uint256).max;
        depositBoost(boostAmount);

        amount %= (boostAmount + 1);
        boostAggregator.withdrawGaugeBoost(receiver, amount);

        checkBoostBalance(receiver, amount);
        checkBoostBalance(address(boostAggregator), boostAmount - amount);
    }

    function test_fail_withdrawGaugeBoost(address user, address receiver, uint256 boostAmount, uint256 amount) public {
        boostAmount %= type(uint256).max;
        depositBoost(boostAmount);

        amount %= (boostAmount + 1);
        if (user != address(this)) hevm.expectRevert(Ownable.Unauthorized.selector);
        hevm.prank(user);
        boostAggregator.withdrawGaugeBoost(receiver, amount);
    }
}
