// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {bHermes} from "@hermes/bHermes.sol";
import {IBaseV2Minter, BaseV2Minter, FlywheelGaugeRewards} from "@hermes/minters/BaseV2Minter.sol";

contract BaseV2MinterTest is DSTestPlus {
    //////////////////////////////////////////////////////////////////
    //                          VARIABLES
    //////////////////////////////////////////////////////////////////
    bHermes bHermesToken;

    BaseV2Minter baseV2Minter;

    FlywheelGaugeRewards flywheelGaugeRewards;

    MockERC20 rewardToken;

    //////////////////////////////////////////////////////////////////
    //                          SET UP
    //////////////////////////////////////////////////////////////////

    function setUp() public {
        rewardToken = new MockERC20("test reward token", "RTKN", 18);

        bHermesToken = new bHermes(rewardToken, address(this), 1 weeks, 12 hours);

        baseV2Minter = new BaseV2Minter(address(bHermesToken), address(this), address(this));

        flywheelGaugeRewards = new FlywheelGaugeRewards(
            address(rewardToken),
            address(this),
            bHermesToken.gaugeWeight(),
            baseV2Minter
        );

        hevm.warp(52 weeks);
    }

    //////////////////////////////////////////////////////////////////
    //                          TESTS
    //////////////////////////////////////////////////////////////////

    function testInitialize() public {
        assertEq(address(baseV2Minter.flywheelGaugeRewards()), address(0));
        assertEq(baseV2Minter.activePeriod(), 0);
        baseV2Minter.initialize(flywheelGaugeRewards);
        assertEq(address(baseV2Minter.flywheelGaugeRewards()), address(flywheelGaugeRewards));
    }

    function testInitializeFail() public {
        hevm.expectRevert(IBaseV2Minter.NotInitializer.selector);
        hevm.prank(address(1));
        baseV2Minter.initialize(flywheelGaugeRewards);
    }

    function testSetDao(address newDao) public {
        assertEq(address(baseV2Minter.dao()), address(this));
        baseV2Minter.setDao(newDao);
        assertEq(address(baseV2Minter.dao()), newDao);
    }

    function testSetDaoShare(uint256 newDaoShare) public {
        newDaoShare %= 301;
        assertEq(baseV2Minter.daoShare(), 100);
        baseV2Minter.setDaoShare(newDaoShare);
        assertEq(baseV2Minter.daoShare(), newDaoShare);
    }

    function testSetDaoShareFail(uint256 newDaoShare) public {
        newDaoShare %= type(uint256).max - 301;
        newDaoShare += 301;
        hevm.expectRevert(IBaseV2Minter.DaoShareTooHigh.selector);
        baseV2Minter.setDaoShare(newDaoShare);
    }

    function testSetTailEmission(uint256 newTailEmission) public {
        newTailEmission %= 101;
        assertEq(baseV2Minter.tailEmission(), 20);
        baseV2Minter.setTailEmission(newTailEmission);
        assertEq(baseV2Minter.tailEmission(), newTailEmission);
    }

    function testSetTailEmissionFail(uint256 newTailEmission) public {
        newTailEmission %= type(uint256).max - 101;
        newTailEmission += 101;
        hevm.expectRevert(IBaseV2Minter.TailEmissionTooHigh.selector);
        baseV2Minter.setTailEmission(newTailEmission);
    }

    function testCirculatingSupply() public {
        assertEq(baseV2Minter.circulatingSupply(), 0);
        baseV2Minter.initialize(flywheelGaugeRewards);
        assertEq(baseV2Minter.circulatingSupply(), 0);
        rewardToken.mint(address(this), 1000);
        assertEq(baseV2Minter.circulatingSupply(), 1000);

        rewardToken.approve(address(bHermesToken), 500);
        bHermesToken.deposit(500, address(this));
        assertEq(baseV2Minter.circulatingSupply(), 500);
    }

    function testWeeklyEmission() public {
        assertEq(baseV2Minter.weeklyEmission(), 0);
        baseV2Minter.initialize(flywheelGaugeRewards);
        assertEq(baseV2Minter.weeklyEmission(), 0);
        rewardToken.mint(address(this), 1000);
        assertEq(baseV2Minter.weeklyEmission(), (1000 * 20) / 1000);

        rewardToken.approve(address(bHermesToken), 500);
        bHermesToken.deposit(500, address(this));
        assertEq(baseV2Minter.weeklyEmission(), (500 * 20) / 1000);
    }

    function testCalculateGrowth() public {
        rewardToken.mint(address(this), 1000);
        assertEq(baseV2Minter.calculateGrowth(1 ether), 0);

        rewardToken.approve(address(bHermesToken), 500);
        bHermesToken.deposit(500, address(this));
        assertEq(baseV2Minter.calculateGrowth(1 ether), 1 ether / 2);

        rewardToken.approve(address(bHermesToken), 500);
        bHermesToken.deposit(500, address(this));
        assertEq(baseV2Minter.calculateGrowth(1 ether), 1 ether);
    }

    function testUpdatePeriod() public {
        rewardToken.mint(address(this), 1000);
        rewardToken.approve(address(bHermesToken), 500);
        bHermesToken.deposit(500, address(this));

        assertEq(baseV2Minter.activePeriod(), 0);
        baseV2Minter.initialize(flywheelGaugeRewards);
        assertEq(baseV2Minter.activePeriod(), block.timestamp);
        hevm.warp(block.timestamp + 1 weeks);

        hevm.expectEmit(true, true, true, true);
        emit Mint(address(this), 10, 500, 5, 1);

        baseV2Minter.updatePeriod();
        assertEq(baseV2Minter.activePeriod(), block.timestamp);

        assertEq(rewardToken.balanceOf(address(bHermesToken)), 505);
        assertEq(rewardToken.balanceOf(address(this)), 501);
    }

    function testUpdatePeriodMinterHasBalance() public {
        rewardToken.mint(address(baseV2Minter), 500);
        rewardToken.mint(address(this), 500);
        rewardToken.approve(address(bHermesToken), 500);
        bHermesToken.deposit(500, address(this));

        assertEq(baseV2Minter.activePeriod(), 0);
        baseV2Minter.initialize(flywheelGaugeRewards);
        assertEq(baseV2Minter.activePeriod(), block.timestamp);
        hevm.warp(block.timestamp + 1 weeks);

        hevm.expectEmit(true, true, true, true);
        emit Mint(address(this), 10, 500, 5, 1);

        baseV2Minter.updatePeriod();
        assertEq(baseV2Minter.activePeriod(), block.timestamp);

        assertEq(rewardToken.balanceOf(address(bHermesToken)), 505);
        assertEq(rewardToken.balanceOf(address(this)), 1);
    }

    function testUpdatePeriodFallback() public {
        rewardToken.mint(address(this), 1000);
        rewardToken.approve(address(bHermesToken), 500);
        bHermesToken.deposit(500, address(this));

        assertEq(baseV2Minter.activePeriod(), 0);
        baseV2Minter.initialize(flywheelGaugeRewards);
        assertEq(baseV2Minter.activePeriod(), block.timestamp);
        hevm.warp(block.timestamp + 1 weeks);

        hevm.expectEmit(true, true, true, true);
        emit Mint(address(this), 10, 500, 5, 1);

        (bool successful,) = address(baseV2Minter).call("");
        assertTrue(successful);

        assertEq(baseV2Minter.activePeriod(), block.timestamp);
        assertEq(rewardToken.balanceOf(address(bHermesToken)), 505);
        assertEq(rewardToken.balanceOf(address(this)), 501);
    }

    function testUpdatePeriodNoDao() public {
        baseV2Minter.setDao(address(0));

        rewardToken.mint(address(this), 1000);
        rewardToken.approve(address(bHermesToken), 500);
        bHermesToken.deposit(500, address(this));

        assertEq(baseV2Minter.activePeriod(), 0);
        baseV2Minter.initialize(flywheelGaugeRewards);
        assertEq(baseV2Minter.activePeriod(), block.timestamp);
        hevm.warp(block.timestamp + 1 weeks);

        hevm.expectEmit(true, true, true, true);
        emit Mint(address(this), 10, 500, 5, 1);

        baseV2Minter.updatePeriod();
        assertEq(baseV2Minter.activePeriod(), block.timestamp);

        assertEq(rewardToken.balanceOf(address(bHermesToken)), 505);
        assertEq(rewardToken.balanceOf(address(this)), 500);
    }

    function testGetRewards() public {
        testUpdatePeriod();

        assertEq(rewardToken.balanceOf(address(flywheelGaugeRewards)), 0);

        hevm.prank(address(flywheelGaugeRewards));
        baseV2Minter.getRewards();

        assertEq(rewardToken.balanceOf(address(flywheelGaugeRewards)), 10);
    }

    function testGetRewardsFail() public {
        testUpdatePeriod();

        hevm.expectRevert(IBaseV2Minter.NotFlywheelGaugeRewards.selector);
        baseV2Minter.getRewards();
    }

    event Mint(address indexed sender, uint256 weekly, uint256 circulatingSupply, uint256 growth, uint256 dao_share);
}
