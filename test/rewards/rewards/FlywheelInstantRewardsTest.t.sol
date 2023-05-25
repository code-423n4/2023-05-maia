// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {FlywheelCoreInstant} from "@rewards/FlywheelCoreInstant.sol";
import {RewardsDepot} from "@rewards/depots/RewardsDepot.sol";

import {FlywheelInstantRewards} from "@rewards/rewards/FlywheelInstantRewards.sol";

contract FlywheelInstantRewardsTest is DSTestPlus {
    FlywheelInstantRewards rewards;

    MockERC20 strategy;
    MockERC20 public rewardToken;
    RewardsDepot depot;

    function setUp() public {
        rewardToken = new MockERC20("test token", "TKN", 18);

        strategy = new MockERC20("test strategy", "TKN", 18);

        rewards = new FlywheelInstantRewards(FlywheelCoreInstant(address(this)));

        depot = rewards.rewardsDepot();

        hevm.prank(address(strategy));
    }

    function testGetAccruedRewardsUninitialized() public {
        assertEq(rewards.getAccruedRewards(), 0 ether);
        assertEq(rewardToken.balanceOf(address(rewards)), 0 ether);
        assertEq(rewardToken.balanceOf(address(depot)), 0 ether);
    }

    function testGetAccruedRewards() public {
        testGetAccruedRewardsUninitialized();

        rewardToken.mint(address(depot), 100 ether);

        assertEq(rewards.getAccruedRewards(), 100 ether);
        assertEq(rewardToken.balanceOf(address(rewards)), 100 ether);
        assertEq(rewardToken.balanceOf(address(depot)), 0 ether);
    }

    function testGetAccruedRewardsTwoCycles() public {
        testGetAccruedRewards();

        hevm.warp(1000);
        rewardToken.mint(address(depot), 100 ether);

        assertEq(rewards.getAccruedRewards(), 100 ether);
        assertEq(rewardToken.balanceOf(address(rewards)), 200 ether);
        assertEq(rewardToken.balanceOf(address(depot)), 0 ether);

        hevm.warp(2000);
        rewardToken.mint(address(depot), 100 ether);

        assertEq(rewards.getAccruedRewards(), 100 ether);
        assertEq(rewardToken.balanceOf(address(rewards)), 300 ether);
        assertEq(rewardToken.balanceOf(address(depot)), 0 ether);
    }

    function testFuzzGetAccruedRewardsUninitialized(uint256 amount) public {
        assertEq(rewards.getAccruedRewards(), 0);
        rewardToken.mint(address(depot), amount);
        assertEq(rewards.getAccruedRewards(), amount);
    }

    function testFuzzGetAccruedRewards(uint256 amount) public {
        rewardToken.mint(address(depot), amount);
        assertEq(rewards.getAccruedRewards(), amount);
        assertEq(rewards.getAccruedRewards(), 0, "Failed Accrue");
    }
}
