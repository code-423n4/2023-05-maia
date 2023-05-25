// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {stdError} from "forge-std/StdError.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {MockBooster} from "../mocks/MockBooster.sol";
import "../mocks/MockRewardsStream.sol";

import {
    MockPartnerUtilityManager,
    IPartnerUtilityManager,
    IUtilityManager,
    UtilityManager
} from "./mocks/MockPartnerUtilityManager.t.sol";

import {bHermesGauges} from "@hermes/tokens/bHermesGauges.sol";
import {bHermesBoost} from "@hermes/tokens/bHermesBoost.sol";
import {bHermesVotes as ERC20Votes} from "@hermes/tokens/bHermesVotes.sol";

import "@rewards/base/FlywheelCore.sol";

// Full integration tests across Flywheel Core, Flywheel Gauge Rewards and bHermes
contract PartnerUtilityManagerTest is DSTestPlus {
    MockPartnerUtilityManager partnerManager;

    function setUp() public {
        partnerManager = new MockPartnerUtilityManager(
            address(new bHermesGauges(address(this), 1 weeks, 1 days / 2)),
            address(new bHermesBoost(address(this))),
            address(new ERC20Votes(address(this))),
            address(new ERC20Votes(address(this))),
            address(0)
        );

        partnerManager.setClaimableWeight(address(this), type(uint256).max);
        partnerManager.setClaimableBoost(address(this), type(uint256).max);
        partnerManager.setClaimableGovernance(address(this), type(uint256).max);
        partnerManager.setClaimablePartnerGovernance(address(this), type(uint256).max);
    }

    function assertAmounts(uint256 weight, uint256 boost, uint256 governance, uint256 partnerGovernance) public {
        assertEq(weight, partnerManager.gaugeWeight().balanceOf(address(this)));
        assertEq(boost, partnerManager.gaugeBoost().balanceOf(address(this)));
        assertEq(governance, partnerManager.governance().balanceOf(address(this)));
        assertEq(partnerGovernance, partnerManager.partnerGovernance().balanceOf(address(this)));

        assertEq(weight, partnerManager.userClaimedWeight(address(this)));
        assertEq(boost, partnerManager.userClaimedBoost(address(this)));
        assertEq(governance, partnerManager.userClaimedGovernance(address(this)));
        assertEq(partnerGovernance, partnerManager.userClaimedPartnerGovernance(address(this)));
    }

    function testClaimInsufficientShares(uint256 amount) public {
        partnerManager.setClaimableWeight(address(this), 0);
        partnerManager.setClaimableBoost(address(this), 0);
        partnerManager.setClaimableGovernance(address(this), 0);
        partnerManager.setClaimablePartnerGovernance(address(this), 0);
        partnerManager.gaugeWeight().mint(address(partnerManager), amount);
        partnerManager.gaugeBoost().mint(address(partnerManager), amount);
        partnerManager.governance().mint(address(partnerManager), amount);
        partnerManager.partnerGovernance().mint(address(partnerManager), amount);

        if (amount != 0) hevm.expectRevert(IUtilityManager.InsufficientShares.selector);
        partnerManager.claimMultiple(amount);

        if (amount != 0) hevm.expectRevert(IUtilityManager.InsufficientShares.selector);
        partnerManager.claimMultipleAmounts(amount, amount, amount, amount);

        if (amount != 0) hevm.expectRevert(IUtilityManager.InsufficientShares.selector);
        partnerManager.claimPartnerGovernance(amount);

        assertAmounts(0, 0, 0, 0);
    }

    function testClaimMultiple(uint256 amount) public {
        partnerManager.gaugeWeight().mint(address(partnerManager), amount);
        partnerManager.gaugeBoost().mint(address(partnerManager), amount);
        partnerManager.governance().mint(address(partnerManager), amount);
        partnerManager.partnerGovernance().mint(address(partnerManager), amount);

        partnerManager.claimMultiple(amount);
        assertAmounts(amount, amount, amount, amount);
    }

    function testClaimMultipleAmounts(uint256 weight, uint256 boost, uint256 governance) public {
        partnerManager.gaugeWeight().mint(address(partnerManager), weight);
        partnerManager.gaugeBoost().mint(address(partnerManager), boost);
        partnerManager.governance().mint(address(partnerManager), governance);
        partnerManager.partnerGovernance().mint(address(partnerManager), governance);

        partnerManager.claimMultipleAmounts(weight, boost, governance);
        assertAmounts(weight, boost, governance, 0);
    }

    function testClaimMultipleAmounts(uint256 weight, uint256 boost, uint256 governance, uint256 partnerGovernance)
        public
    {
        partnerManager.gaugeWeight().mint(address(partnerManager), weight);
        partnerManager.gaugeBoost().mint(address(partnerManager), boost);
        partnerManager.governance().mint(address(partnerManager), governance);
        partnerManager.partnerGovernance().mint(address(partnerManager), partnerGovernance);

        partnerManager.claimMultipleAmounts(weight, boost, governance, partnerGovernance);
        assertAmounts(weight, boost, governance, partnerGovernance);
    }

    function testClaimPartnerGovernance(uint256 amount) public {
        partnerManager.partnerGovernance().mint(address(partnerManager), amount);

        partnerManager.claimPartnerGovernance(amount);
        assertAmounts(0, 0, 0, amount);
    }

    function testForfeitMultiple(uint256 amount) public {
        testClaimMultiple(amount);

        partnerManager.gaugeWeight().approve(address(partnerManager), amount);
        partnerManager.gaugeBoost().approve(address(partnerManager), amount);
        partnerManager.governance().approve(address(partnerManager), amount);
        partnerManager.partnerGovernance().approve(address(partnerManager), amount);

        partnerManager.forfeitMultiple(amount);
        assertAmounts(0, 0, 0, 0);
    }

    function testForfeitMultipleAmounts(uint256 weight, uint256 boost, uint256 governance) public {
        testClaimMultipleAmounts(weight, boost, governance);

        partnerManager.gaugeWeight().approve(address(partnerManager), weight);
        partnerManager.gaugeBoost().approve(address(partnerManager), boost);
        partnerManager.governance().approve(address(partnerManager), governance);
        partnerManager.partnerGovernance().approve(address(partnerManager), governance);

        partnerManager.forfeitMultipleAmounts(weight, boost, governance);
        assertAmounts(0, 0, 0, 0);
    }

    function testForfeitMultipleAmounts(uint256 weight, uint256 boost, uint256 governance, uint256 partnerGovernance)
        public
    {
        testClaimMultipleAmounts(weight, boost, governance, partnerGovernance);

        partnerManager.gaugeWeight().approve(address(partnerManager), weight);
        partnerManager.gaugeBoost().approve(address(partnerManager), boost);
        partnerManager.governance().approve(address(partnerManager), governance);
        partnerManager.partnerGovernance().approve(address(partnerManager), partnerGovernance);

        partnerManager.forfeitMultipleAmounts(weight, boost, governance, partnerGovernance);
        assertAmounts(0, 0, 0, 0);
    }

    function testForfeitPartnerGovernance(uint256 amount) public {
        testClaimPartnerGovernance(amount);

        partnerManager.partnerGovernance().approve(address(partnerManager), amount);

        partnerManager.forfeitPartnerGovernance(amount);
        assertAmounts(0, 0, 0, 0);
    }

    function testForfeitMultipleOverflow(uint256 amount) public {
        amount %= type(uint256).max;

        testClaimMultiple(amount);

        ++amount;
        partnerManager.gaugeWeight().approve(address(partnerManager), amount);
        partnerManager.gaugeBoost().approve(address(partnerManager), amount);
        partnerManager.governance().approve(address(partnerManager), amount);
        partnerManager.partnerGovernance().approve(address(partnerManager), amount);

        hevm.expectRevert(stdError.arithmeticError);
        partnerManager.forfeitMultiple(amount);
    }

    function testForfeitMultipleAmountsOverflow(uint256 weight, uint256 boost, uint256 governance) public {
        weight %= type(uint256).max;
        boost %= type(uint256).max;
        governance %= type(uint256).max;

        testClaimMultipleAmounts(weight, boost, governance);

        ++weight;
        ++boost;
        ++governance;
        partnerManager.gaugeWeight().approve(address(partnerManager), weight);
        partnerManager.gaugeBoost().approve(address(partnerManager), boost);
        partnerManager.governance().approve(address(partnerManager), governance);
        partnerManager.partnerGovernance().approve(address(partnerManager), governance);

        hevm.expectRevert(stdError.arithmeticError);
        partnerManager.forfeitMultipleAmounts(weight, boost, governance);
    }

    function testForfeitMultipleAmountsOverflow(
        uint256 weight,
        uint256 boost,
        uint256 governance,
        uint256 partnerGovernance
    ) public {
        weight %= type(uint256).max;
        boost %= type(uint256).max;
        governance %= type(uint256).max;
        partnerGovernance %= type(uint256).max;

        testClaimMultipleAmounts(weight, boost, governance, partnerGovernance);

        ++weight;
        ++boost;
        ++governance;
        ++partnerGovernance;
        partnerManager.gaugeWeight().approve(address(partnerManager), weight);
        partnerManager.gaugeBoost().approve(address(partnerManager), boost);
        partnerManager.governance().approve(address(partnerManager), governance);
        partnerManager.partnerGovernance().approve(address(partnerManager), partnerGovernance);

        hevm.expectRevert(stdError.arithmeticError);
        partnerManager.forfeitMultipleAmounts(weight, boost, governance, partnerGovernance);
    }

    function testForfeitPartnerGovernanceOverflow(uint256 amount) public {
        amount %= type(uint256).max;

        testClaimPartnerGovernance(amount);

        ++amount;
        partnerManager.partnerGovernance().approve(address(partnerManager), amount);

        hevm.expectRevert(stdError.arithmeticError);
        partnerManager.forfeitPartnerGovernance(amount);
    }

    function testForfeitMultipleZero(uint256 amount) public {
        testClaimMultiple(amount);

        partnerManager.gaugeWeight().approve(address(partnerManager), amount);
        partnerManager.gaugeBoost().approve(address(partnerManager), amount);
        partnerManager.governance().approve(address(partnerManager), amount);
        partnerManager.partnerGovernance().approve(address(partnerManager), amount);

        partnerManager.forfeitMultiple(0);
        assertAmounts(amount, amount, amount, amount);
    }

    function testForfeitMultipleAmountsZero(uint256 weight, uint256 boost, uint256 governance) public {
        testClaimMultipleAmounts(weight, boost, governance);

        partnerManager.gaugeWeight().approve(address(partnerManager), weight);
        partnerManager.gaugeBoost().approve(address(partnerManager), boost);
        partnerManager.governance().approve(address(partnerManager), governance);
        partnerManager.partnerGovernance().approve(address(partnerManager), governance);

        partnerManager.forfeitMultipleAmounts(0, 0, 0);
        assertAmounts(weight, boost, governance, 0);
    }

    function testForfeitMultipleAmountsZero(
        uint256 weight,
        uint256 boost,
        uint256 governance,
        uint256 partnerGovernance
    ) public {
        testClaimMultipleAmounts(weight, boost, governance, partnerGovernance);

        partnerManager.gaugeWeight().approve(address(partnerManager), weight);
        partnerManager.gaugeBoost().approve(address(partnerManager), boost);
        partnerManager.governance().approve(address(partnerManager), governance);
        partnerManager.partnerGovernance().approve(address(partnerManager), partnerGovernance);

        partnerManager.forfeitMultipleAmounts(0, 0, 0, 0);
        assertAmounts(weight, boost, governance, partnerGovernance);
    }

    function testForfeitPartnerGovernanceZero(uint256 amount) public {
        testClaimPartnerGovernance(amount);

        partnerManager.partnerGovernance().approve(address(partnerManager), amount);

        partnerManager.forfeitPartnerGovernance(0);
        assertAmounts(0, 0, 0, amount);
    }

    function testForfeitMultipleNotEnoughBalance(uint256 amount) public {
        amount %= type(uint256).max;

        testClaimMultiple(amount);

        partnerManager.gaugeWeight().approve(address(partnerManager), amount);
        partnerManager.gaugeBoost().approve(address(partnerManager), amount);
        partnerManager.governance().approve(address(partnerManager), amount);
        partnerManager.partnerGovernance().approve(address(partnerManager), amount);

        ++amount;
        hevm.expectRevert(stdError.arithmeticError);
        partnerManager.forfeitMultiple(amount);
    }

    function testForfeitMultipleAmountsNotEnoughBalance(uint256 weight, uint256 boost, uint256 governance) public {
        weight %= type(uint256).max;
        boost %= type(uint256).max;
        governance %= type(uint256).max;

        testClaimMultipleAmounts(weight, boost, governance);

        partnerManager.gaugeWeight().approve(address(partnerManager), weight);
        partnerManager.gaugeBoost().approve(address(partnerManager), boost);
        partnerManager.governance().approve(address(partnerManager), governance);
        partnerManager.partnerGovernance().approve(address(partnerManager), governance);

        ++weight;
        ++boost;
        ++governance;
        hevm.expectRevert(stdError.arithmeticError);
        partnerManager.forfeitMultipleAmounts(weight, boost, governance);
    }

    function testForfeitMultipleAmountsNotEnoughBalance(
        uint256 weight,
        uint256 boost,
        uint256 governance,
        uint256 partnerGovernance
    ) public {
        weight %= type(uint256).max;
        boost %= type(uint256).max;
        governance %= type(uint256).max;
        partnerGovernance %= type(uint256).max;

        testClaimMultipleAmounts(weight, boost, governance, partnerGovernance);

        partnerManager.gaugeWeight().approve(address(partnerManager), weight);
        partnerManager.gaugeBoost().approve(address(partnerManager), boost);
        partnerManager.governance().approve(address(partnerManager), governance);
        partnerManager.partnerGovernance().approve(address(partnerManager), partnerGovernance);

        ++weight;
        ++boost;
        ++governance;
        ++partnerGovernance;
        hevm.expectRevert(stdError.arithmeticError);
        partnerManager.forfeitMultipleAmounts(weight, boost, governance, partnerGovernance);
    }

    function testForfeitPartnerGovernanceNotEnoughBalance(uint256 amount) public {
        amount %= type(uint256).max;

        testClaimPartnerGovernance(amount);

        partnerManager.partnerGovernance().approve(address(partnerManager), amount);

        ++amount;
        hevm.expectRevert(stdError.arithmeticError);
        partnerManager.forfeitPartnerGovernance(amount);
    }

    function testForfeitMultipleNotEnoughClaimed(uint256 amount) public {
        amount %= type(uint256).max;
        ++amount;

        testClaimMultiple(amount);

        partnerManager.gaugeWeight().approve(address(partnerManager), amount);
        partnerManager.gaugeBoost().approve(address(partnerManager), amount);
        partnerManager.governance().approve(address(partnerManager), amount);
        partnerManager.partnerGovernance().approve(address(partnerManager), amount);

        hevm.expectRevert(stdError.arithmeticError);
        hevm.prank(address(1));
        partnerManager.forfeitMultiple(amount);
    }

    function testForfeitMultipleAmountsNotEnoughClaimed(uint256 weight, uint256 boost, uint256 governance) public {
        weight %= type(uint256).max;
        boost %= type(uint256).max;
        governance %= type(uint256).max;
        ++weight;
        ++boost;
        ++governance;

        testClaimMultipleAmounts(weight, boost, governance);

        partnerManager.gaugeWeight().approve(address(partnerManager), weight);
        partnerManager.gaugeBoost().approve(address(partnerManager), boost);
        partnerManager.governance().approve(address(partnerManager), governance);

        hevm.expectRevert(stdError.arithmeticError);
        hevm.prank(address(1));
        partnerManager.forfeitMultipleAmounts(weight, boost, governance);
    }

    function testForfeitMultipleAmountsNotEnoughClaimed(
        uint256 weight,
        uint256 boost,
        uint256 governance,
        uint256 partnerGovernance
    ) public {
        weight %= type(uint256).max;
        boost %= type(uint256).max;
        governance %= type(uint256).max;
        partnerGovernance %= type(uint256).max;
        ++weight;
        ++boost;
        ++governance;
        ++partnerGovernance;

        testClaimMultipleAmounts(weight, boost, governance, partnerGovernance);

        partnerManager.gaugeWeight().approve(address(partnerManager), weight);
        partnerManager.gaugeBoost().approve(address(partnerManager), boost);
        partnerManager.governance().approve(address(partnerManager), governance);
        partnerManager.partnerGovernance().approve(address(partnerManager), partnerGovernance);

        hevm.expectRevert(stdError.arithmeticError);
        hevm.prank(address(1));
        partnerManager.forfeitMultipleAmounts(weight, boost, governance, partnerGovernance);
    }

    function testForfeitPartnerGovernanceNotEnoughClaimed(uint256 amount) public {
        amount %= type(uint256).max;
        ++amount;

        testClaimPartnerGovernance(amount);

        partnerManager.partnerGovernance().approve(address(partnerManager), amount);

        hevm.expectRevert(stdError.arithmeticError);
        hevm.prank(address(1));
        partnerManager.forfeitPartnerGovernance(amount);
    }
}
