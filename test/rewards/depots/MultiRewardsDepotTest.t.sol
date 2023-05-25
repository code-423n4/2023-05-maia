// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {MultiRewardsDepot} from "@rewards/depots/MultiRewardsDepot.sol";

import {Ownable} from "solady/auth/Ownable.sol";

contract MultiRewardsDepotTest is DSTestPlus {
    MockERC20 public rewardToken;
    MultiRewardsDepot public depot;

    function setUp() public {
        rewardToken = new MockERC20("test token", "TKN", 18);

        depot = new MultiRewardsDepot(address(this));
        depot.addAsset(address(this), address(rewardToken));
    }

    function testAddAsset() public {
        depot.addAsset(address(1), address(2));
    }

    function testAddAsset(address flywheelRewards, address asset) public {
        hevm.assume(asset != address(0) && asset != address(rewardToken));
        depot.addAsset(flywheelRewards, asset);
    }

    function testAddAssetAlreadyExists() public {
        hevm.expectRevert(abi.encodeWithSignature("ErrorAddingAsset()"));
        depot.addAsset(address(this), address(rewardToken));
    }

    function testAddAssetAlreadyExists(address flywheelRewards) public {
        hevm.expectRevert(abi.encodeWithSignature("ErrorAddingAsset()"));
        depot.addAsset(flywheelRewards, address(rewardToken));
    }

    function testGetRewards() public {
        testAddAsset();
        rewardToken.mint(address(depot), 100 ether);

        depot.getRewards();

        assertEq(rewardToken.balanceOf(address(this)), 100 ether);
    }

    function testGetRewardsNoAvailable() public {
        testAddAsset();
        depot.getRewards();

        assertEq(rewardToken.balanceOf(address(this)), 0);
    }

    function testGetRewardsNotAllowed() public {
        testAddAsset();
        rewardToken.mint(address(depot), 100 ether);

        hevm.prank(address(2));
        hevm.expectRevert(abi.encodeWithSignature("FlywheelRewardsError()"));
        depot.getRewards();
    }

    function testGetRewardsTwice() public {
        testAddAsset();
        rewardToken.mint(address(depot), 100 ether);

        depot.getRewards();

        assertEq(rewardToken.balanceOf(address(this)), 100 ether);

        rewardToken.mint(address(depot), 100 ether);

        depot.getRewards();

        assertEq(rewardToken.balanceOf(address(this)), 200 ether);
    }

    function testGetRewardsTwiceFirstHasNothing() public {
        testAddAsset();
        depot.getRewards();

        assertEq(rewardToken.balanceOf(address(this)), 0 ether);

        rewardToken.mint(address(depot), 100 ether);

        depot.getRewards();

        assertEq(rewardToken.balanceOf(address(this)), 100 ether);
    }

    function testGetRewardsTwiceSecondHasNothing() public {
        testAddAsset();
        rewardToken.mint(address(depot), 100 ether);

        depot.getRewards();

        assertEq(rewardToken.balanceOf(address(this)), 100 ether);

        depot.getRewards();

        assertEq(rewardToken.balanceOf(address(this)), 100 ether);
    }
}
