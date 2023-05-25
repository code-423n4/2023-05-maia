// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {stdError} from "forge-std/StdError.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {MockBooster} from "../mocks/MockBooster.sol";
import "../mocks/MockRewardsStream.sol";

import {MockUtilityManager, UtilityManager} from "./mocks/MockUtilityManager.t.sol";

import {bHermesGauges} from "@hermes/tokens/bHermesGauges.sol";
import {bHermesBoost} from "@hermes/tokens/bHermesBoost.sol";
import {bHermesVotes as ERC20Votes} from "@hermes/tokens/bHermesVotes.sol";

import "@rewards/base/FlywheelCore.sol";
import {FlywheelGaugeRewards, IBaseV2Minter} from "@rewards/rewards/FlywheelGaugeRewards.sol";

// Full integration tests across Flywheel Core, Flywheel Gauge Rewards and bHermes
contract UtilityManagerTest is DSTestPlus {
    MockUtilityManager utilityManager;

    function setUp() public {
        utilityManager = new MockUtilityManager(
            address(new bHermesGauges(address(this), 1 weeks, 1 days / 2)),
            address(new bHermesBoost(address(this))),
            address(new ERC20Votes(address(this)))
        );

        utilityManager.setClaimableWeight(address(this), type(uint256).max);
        utilityManager.setClaimableBoost(address(this), type(uint256).max);
        utilityManager.setClaimableGovernance(address(this), type(uint256).max);
    }

    function assertAmounts(uint256 weight, uint256 boost, uint256 governance) public {
        assertEq(weight, utilityManager.gaugeWeight().balanceOf(address(this)));
        assertEq(boost, utilityManager.gaugeBoost().balanceOf(address(this)));
        assertEq(governance, utilityManager.governance().balanceOf(address(this)));

        assertEq(weight, utilityManager.userClaimedWeight(address(this)));
        assertEq(boost, utilityManager.userClaimedBoost(address(this)));
        assertEq(governance, utilityManager.userClaimedGovernance(address(this)));
    }

    function testClaimMultiple(uint256 amount) public {
        utilityManager.gaugeWeight().mint(address(utilityManager), amount);
        utilityManager.gaugeBoost().mint(address(utilityManager), amount);
        utilityManager.governance().mint(address(utilityManager), amount);

        utilityManager.claimMultiple(amount);
        assertAmounts(amount, amount, amount);
    }

    function testClaimMultipleAmounts(uint256 weight, uint256 boost, uint256 governance) public {
        utilityManager.gaugeWeight().mint(address(utilityManager), weight);
        utilityManager.gaugeBoost().mint(address(utilityManager), boost);
        utilityManager.governance().mint(address(utilityManager), governance);

        utilityManager.claimMultipleAmounts(weight, boost, governance);
        assertAmounts(weight, boost, governance);
    }

    function testClaimWeight(uint256 amount) public {
        utilityManager.gaugeWeight().mint(address(utilityManager), amount);

        utilityManager.claimWeight(amount);
        assertAmounts(amount, 0, 0);
    }

    function testClaimBoost(uint256 amount) public {
        utilityManager.gaugeBoost().mint(address(utilityManager), amount);

        utilityManager.claimBoost(amount);
        assertAmounts(0, amount, 0);
    }

    function testClaimGovernance(uint256 amount) public {
        utilityManager.governance().mint(address(utilityManager), amount);

        utilityManager.claimGovernance(amount);
        assertAmounts(0, 0, amount);
    }

    function testForfeitMultiple(uint256 amount) public {
        testClaimMultiple(amount);

        utilityManager.gaugeWeight().approve(address(utilityManager), amount);
        utilityManager.gaugeBoost().approve(address(utilityManager), amount);
        utilityManager.governance().approve(address(utilityManager), amount);

        utilityManager.forfeitMultiple(amount);
        assertAmounts(0, 0, 0);
    }

    function testForfeitMultipleAmounts(uint256 weight, uint256 boost, uint256 governance) public {
        testClaimMultipleAmounts(weight, boost, governance);

        utilityManager.gaugeWeight().approve(address(utilityManager), weight);
        utilityManager.gaugeBoost().approve(address(utilityManager), boost);
        utilityManager.governance().approve(address(utilityManager), governance);

        utilityManager.forfeitMultipleAmounts(weight, boost, governance);
        assertAmounts(0, 0, 0);
    }

    function testForfeitWeight(uint256 amount) public {
        testClaimWeight(amount);

        utilityManager.gaugeWeight().approve(address(utilityManager), amount);

        utilityManager.forfeitWeight(amount);
        assertAmounts(0, 0, 0);
    }

    function testForfeitBoost(uint256 amount) public {
        testClaimBoost(amount);

        utilityManager.gaugeBoost().approve(address(utilityManager), amount);

        utilityManager.forfeitBoost(amount);
        assertAmounts(0, 0, 0);
    }

    function testForfeitGovernance(uint256 amount) public {
        testClaimGovernance(amount);

        utilityManager.governance().approve(address(utilityManager), amount);

        utilityManager.forfeitGovernance(amount);
        assertAmounts(0, 0, 0);
    }

    function testForfeitMultipleOverflow(uint256 amount) public {
        amount %= type(uint256).max;

        testClaimMultiple(amount);

        ++amount;
        utilityManager.gaugeWeight().approve(address(utilityManager), amount);
        utilityManager.gaugeBoost().approve(address(utilityManager), amount);
        utilityManager.governance().approve(address(utilityManager), amount);

        hevm.expectRevert(stdError.arithmeticError);
        utilityManager.forfeitMultiple(amount);
    }

    function testForfeitMultipleAmountsOverflow(uint256 weight, uint256 boost, uint256 governance) public {
        weight %= type(uint256).max;
        boost %= type(uint256).max;
        governance %= type(uint256).max;

        testClaimMultipleAmounts(weight, boost, governance);

        ++weight;
        ++boost;
        ++governance;
        utilityManager.gaugeWeight().approve(address(utilityManager), weight);
        utilityManager.gaugeBoost().approve(address(utilityManager), boost);
        utilityManager.governance().approve(address(utilityManager), governance);

        hevm.expectRevert(stdError.arithmeticError);
        utilityManager.forfeitMultipleAmounts(weight, boost, governance);
    }

    function testForfeitWeightOverflow(uint256 amount) public {
        amount %= type(uint256).max;

        testClaimWeight(amount);

        ++amount;
        utilityManager.gaugeWeight().approve(address(utilityManager), amount);

        hevm.expectRevert(stdError.arithmeticError);
        utilityManager.forfeitWeight(amount);
    }

    function testForfeitBoostOverflow(uint256 amount) public {
        amount %= type(uint256).max;

        testClaimBoost(amount);

        ++amount;
        utilityManager.gaugeBoost().approve(address(utilityManager), amount);

        hevm.expectRevert(stdError.arithmeticError);
        utilityManager.forfeitBoost(amount);
    }

    function testForfeitGovernanceOverflow(uint256 amount) public {
        amount %= type(uint256).max;

        testClaimGovernance(amount);

        ++amount;
        utilityManager.governance().approve(address(utilityManager), amount);

        hevm.expectRevert(stdError.arithmeticError);
        utilityManager.forfeitGovernance(amount);
    }

    function testForfeitMultipleZero(uint256 amount) public {
        testClaimMultiple(amount);

        utilityManager.gaugeWeight().approve(address(utilityManager), amount);
        utilityManager.gaugeBoost().approve(address(utilityManager), amount);
        utilityManager.governance().approve(address(utilityManager), amount);

        utilityManager.forfeitMultiple(0);
        assertAmounts(amount, amount, amount);
    }

    function testForfeitMultipleAmountsZero(uint256 weight, uint256 boost, uint256 governance) public {
        testClaimMultipleAmounts(weight, boost, governance);

        utilityManager.gaugeWeight().approve(address(utilityManager), weight);
        utilityManager.gaugeBoost().approve(address(utilityManager), boost);
        utilityManager.governance().approve(address(utilityManager), governance);

        utilityManager.forfeitMultipleAmounts(0, 0, 0);
        assertAmounts(weight, boost, governance);
    }

    function testForfeitWeightZero(uint256 amount) public {
        testClaimWeight(amount);

        utilityManager.gaugeWeight().approve(address(utilityManager), amount);

        utilityManager.forfeitWeight(0);
        assertAmounts(amount, 0, 0);
    }

    function testForfeitBoostZero(uint256 amount) public {
        testClaimBoost(amount);

        utilityManager.gaugeBoost().approve(address(utilityManager), amount);

        utilityManager.forfeitBoost(0);
        assertAmounts(0, amount, 0);
    }

    function testForfeitGovernanceZero(uint256 amount) public {
        testClaimGovernance(amount);

        utilityManager.governance().approve(address(utilityManager), amount);

        utilityManager.forfeitGovernance(0);
        assertAmounts(0, 0, amount);
    }

    function testForfeitMultipleNotEnoughBalance(uint256 amount) public {
        amount %= type(uint256).max;

        testClaimMultiple(amount);

        utilityManager.gaugeWeight().approve(address(utilityManager), amount);
        utilityManager.gaugeBoost().approve(address(utilityManager), amount);
        utilityManager.governance().approve(address(utilityManager), amount);

        ++amount;
        hevm.expectRevert(stdError.arithmeticError);
        utilityManager.forfeitMultiple(amount);
    }

    function testForfeitMultipleAmountsNotEnoughBalance(uint256 weight, uint256 boost, uint256 governance) public {
        weight %= type(uint256).max;
        boost %= type(uint256).max;
        governance %= type(uint256).max;

        testClaimMultipleAmounts(weight, boost, governance);

        utilityManager.gaugeWeight().approve(address(utilityManager), weight);
        utilityManager.gaugeBoost().approve(address(utilityManager), boost);
        utilityManager.governance().approve(address(utilityManager), governance);

        ++weight;
        ++boost;
        ++governance;
        hevm.expectRevert(stdError.arithmeticError);
        utilityManager.forfeitMultipleAmounts(weight, boost, governance);
    }

    function testForfeitWeightNotEnoughBalance(uint256 amount) public {
        amount %= type(uint256).max;

        testClaimWeight(amount);

        utilityManager.gaugeWeight().approve(address(utilityManager), amount);

        ++amount;
        hevm.expectRevert(stdError.arithmeticError);
        utilityManager.forfeitWeight(amount);
    }

    function testForfeitBoostNotEnoughBalance(uint256 amount) public {
        amount %= type(uint256).max;

        testClaimBoost(amount);

        utilityManager.gaugeBoost().approve(address(utilityManager), amount);

        ++amount;
        hevm.expectRevert(stdError.arithmeticError);
        utilityManager.forfeitBoost(amount);
    }

    function testForfeitGovernanceNotEnoughBalance(uint256 amount) public {
        amount %= type(uint256).max;

        testClaimGovernance(amount);

        utilityManager.governance().approve(address(utilityManager), amount);

        ++amount;
        hevm.expectRevert(stdError.arithmeticError);
        utilityManager.forfeitGovernance(amount);
    }

    function testForfeitMultipleNotEnoughClaimed(uint256 amount) public {
        amount %= type(uint256).max;
        ++amount;

        testClaimMultiple(amount);

        utilityManager.gaugeWeight().approve(address(utilityManager), amount);
        utilityManager.gaugeBoost().approve(address(utilityManager), amount);
        utilityManager.governance().approve(address(utilityManager), amount);

        hevm.expectRevert(stdError.arithmeticError);
        hevm.prank(address(1));
        utilityManager.forfeitMultiple(amount);
    }

    function testForfeitMultipleAmountsNotEnoughClaimed(uint256 weight, uint256 boost, uint256 governance) public {
        weight %= type(uint256).max;
        boost %= type(uint256).max;
        governance %= type(uint256).max;
        ++weight;
        ++boost;
        ++governance;

        testClaimMultipleAmounts(weight, boost, governance);

        utilityManager.gaugeWeight().approve(address(utilityManager), weight);
        utilityManager.gaugeBoost().approve(address(utilityManager), boost);
        utilityManager.governance().approve(address(utilityManager), governance);

        hevm.expectRevert(stdError.arithmeticError);
        hevm.prank(address(1));
        utilityManager.forfeitMultipleAmounts(weight, boost, governance);
    }

    function testForfeitWeightNotEnoughClaimed(uint256 amount) public {
        amount %= type(uint256).max;
        ++amount;

        testClaimWeight(amount);

        utilityManager.gaugeWeight().approve(address(utilityManager), amount);

        hevm.expectRevert(stdError.arithmeticError);
        hevm.prank(address(1));
        utilityManager.forfeitWeight(amount);
    }

    function testForfeitBoostNotEnoughClaimed(uint256 amount) public {
        amount %= type(uint256).max;
        ++amount;

        testClaimBoost(amount);

        utilityManager.gaugeBoost().approve(address(utilityManager), amount);

        hevm.expectRevert(stdError.arithmeticError);
        hevm.prank(address(1));
        utilityManager.forfeitBoost(amount);
    }

    function testForfeitGovernanceNotEnoughClaimed(uint256 amount) public {
        amount %= type(uint256).max;
        ++amount;

        testClaimGovernance(amount);

        utilityManager.governance().approve(address(utilityManager), amount);

        hevm.expectRevert(stdError.arithmeticError);
        hevm.prank(address(1));
        utilityManager.forfeitGovernance(amount);
    }
}
