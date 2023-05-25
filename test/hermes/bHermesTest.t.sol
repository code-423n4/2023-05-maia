// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {MockBooster} from "../mocks/MockBooster.sol";
import "../mocks/MockRewardsStream.sol";

import {bHermes as bHERMES} from "@hermes/bHermes.sol";
import {IUtilityManager} from "@hermes/interfaces/IUtilityManager.sol";

import "@rewards/base/FlywheelCore.sol";
import {FlywheelGaugeRewards, IBaseV2Minter} from "@rewards/rewards/FlywheelGaugeRewards.sol";

contract bHermesTest is DSTestPlus {
    FlywheelCore flywheel;
    FlywheelGaugeRewards rewards;
    MockRewardsStream stream;

    MockERC20 strategy;
    MockERC20 hermes;
    MockBooster booster;

    bHERMES bHermes;

    function setUp() public {
        hermes = new MockERC20("test hermes", "TKN", 18);

        strategy = new MockERC20("test strategy", "TKN", 18);

        bHermes = new bHERMES(
            hermes,
            address(this),
            1000, // cycle of 1000
            100 // freeze window of 100
        );

        rewards = new FlywheelGaugeRewards(
            address(hermes),
            address(this),
            bHermes.gaugeWeight(),
            IBaseV2Minter(address(stream))
        );
    }

    function mintHelper(uint256 amount, address user) internal {
        hermes.mint(user, amount);
        hermes.approve(address(bHermes), amount);
        bHermes.previewDeposit(amount);
        bHermes.deposit(amount, user);
    }

    function testClaimMultipleInsufficientShares(uint256 amount) public {
        if (amount != 0) hevm.expectRevert(IUtilityManager.InsufficientShares.selector);
        bHermes.claimMultiple(amount);
    }

    function testClaimMultipleInsufficientShares(uint256 amount, address user) public {
        if (amount != 0) {
            hevm.startPrank(user);
            mintHelper(amount, user);
            hevm.stopPrank();
        }
        testClaimMultipleInsufficientShares(amount);
    }

    function testClaimMultipleInsufficientShares(uint256 amount, uint256 diff) public {
        diff %= type(uint256).max - 1;
        amount %= type(uint256).max - ++diff;
        if (amount != 0) {
            mintHelper(amount, address(this));
        }
        amount += diff;
        testClaimMultipleInsufficientShares(amount);
    }

    function testClaimMultipleAmountsInsufficientShares(uint256 weight, uint256 boost, uint256 governance) public {
        if (weight != 0 || boost != 0 || governance != 0) {
            hevm.expectRevert(IUtilityManager.InsufficientShares.selector);
        }
        bHermes.claimMultipleAmounts(weight, boost, governance);
    }

    function testClaimWeightInsufficientShares(uint256 amount) public {
        if (amount != 0) hevm.expectRevert(IUtilityManager.InsufficientShares.selector);
        bHermes.claimWeight(amount);
    }

    function testClaimBoostInsufficientShares(uint256 amount) public {
        if (amount != 0) hevm.expectRevert(IUtilityManager.InsufficientShares.selector);
        bHermes.claimBoost(amount);
    }

    function testClaimGovernanceInsufficientShares(uint256 amount) public {
        if (amount != 0) hevm.expectRevert(IUtilityManager.InsufficientShares.selector);
        bHermes.claimGovernance(amount);
    }

    function testMint() public {
        uint256 amount = 100 ether;
        hermes.mint(address(this), 100 ether);
        hermes.approve(address(bHermes), amount);
        bHermes.mint(amount, address(1));
        assertEq(bHermes.balanceOf(address(1)), amount);
        assertEq(bHermes.gaugeWeight().balanceOf(address(bHermes)), amount);
        assertEq(bHermes.gaugeBoost().balanceOf(address(bHermes)), amount);
        assertEq(bHermes.governance().balanceOf(address(bHermes)), amount);
    }

    function testTransfer() public {
        testMint();
        hevm.prank(address(1));
        bHermes.transfer(address(2), 100 ether);
        assertEq(bHermes.balanceOf(address(1)), 0);
        assertEq(bHermes.balanceOf(address(2)), 100 ether);

        assertEq(bHermes.gaugeWeight().balanceOf(address(1)), 0);
        assertEq(bHermes.gaugeWeight().balanceOf(address(bHermes)), 100 ether);

        assertEq(bHermes.gaugeBoost().balanceOf(address(1)), 0);
        assertEq(bHermes.gaugeBoost().balanceOf(address(bHermes)), 100 ether);

        assertEq(bHermes.governance().balanceOf(address(1)), 0);
        assertEq(bHermes.governance().balanceOf(address(bHermes)), 100 ether);
    }

    function testTransferFailed() public {
        testMint();
        hevm.prank(address(1));
        bHermes.claimWeight(1);
        hevm.expectRevert(abi.encodeWithSignature("InsufficientUnderlying()"));
        bHermes.transfer(address(2), 100 ether);
    }
}
