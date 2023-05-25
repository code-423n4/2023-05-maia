// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";

import {MockBaseV2Gauge} from "../gauges/mocks/MockBaseV2Gauge.sol";

import {MockERC20Boost, IERC20Boost, ERC20Boost, ERC20} from "./mocks/MockERC20Boost.t.sol";

import {FlywheelGaugeRewards} from "@rewards/rewards/FlywheelGaugeRewards.sol";

contract ERC20BoostTest is DSTestPlus {
    MockERC20Boost token;
    address gauge1;
    address gauge2;

    function setUp() public {
        token = new MockERC20Boost(); // 1 hour cycles, 10 minute freeze

        hevm.mockCall(address(0), abi.encodeWithSignature("rewardToken()"), abi.encode(ERC20(address(0xDEAD))));
        hevm.mockCall(address(0), abi.encodeWithSignature("gaugeToken()"), abi.encode(ERC20Boost(address(0xBEEF))));
        hevm.mockCall(address(this), abi.encodeWithSignature("bHermesBoostToken()"), abi.encode(token));

        gauge1 = address(new MockBaseV2Gauge(FlywheelGaugeRewards(address(0)), address(0), address(0)));
        gauge2 = address(new MockBaseV2Gauge(FlywheelGaugeRewards(address(0)), address(0), address(0)));
    }

    /*///////////////////////////////////////////////////////////////
                            VIEW OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function testGauges() public {
        assertEq(token.gauges().length, 0);
        testAddGauge();
        assertEq(token.gauges().length, 1);
    }

    function testGaugesOffset() public {
        assertEq(token.gauges().length, 0);
        testAddGaugeTwice();
        assertEq(token.gauges().length, 2);
        assertEq(token.gauges(1, 1)[0], gauge2);
    }

    function testIsGauge() public {
        assertFalse(token.isGauge(gauge1));
        testAddGauge();
        assertTrue(token.isGauge(gauge1));

        token.removeGauge(gauge1);
        require(token.deprecatedGauges()[0] == gauge1, "gauge1 not removed");
        assertFalse(token.isGauge(gauge1));
    }

    function testNumGauges() public {
        assertEq(token.numGauges(), 0);
        testAddGauge();
        assertEq(token.numGauges(), 1);
    }

    function testDeprecatedGauges() public {
        assertEq(token.deprecatedGauges().length, 0);
        testRemoveGauge();
        assertEq(token.deprecatedGauges().length, 1);
    }

    function testFreeGaugeBoost() public {
        assertEq(token.freeGaugeBoost(address(1)), 0);
        testAttach();
        assertEq(token.freeGaugeBoost(address(1)), 0);
        token.mint(address(1), 100 ether);
        assertEq(token.freeGaugeBoost(address(1)), 100 ether);
    }

    function testUserGauges() public {
        assertEq(token.userGauges(address(1)).length, 0);
        testAttach();
        assertEq(token.userGauges(address(1)).length, 1);

        hevm.prank(gauge1);
        token.detach(address(1));
        assertEq(token.userGauges(address(1)).length, 0);
    }

    function testUserGaugesOffset() public {
        assertEq(token.userGauges(address(1)).length, 0);
        testAttachTwoGauges();
        assertEq(token.userGauges(address(1)).length, 2);
        assertEq(token.userGauges(address(1), 1, 1)[0], gauge2);
    }

    function testNumUserGauges() public {
        assertEq(token.numUserGauges(address(1)), 0);
        testAttach();
        assertEq(token.numUserGauges(address(1)), 1);
    }

    /*///////////////////////////////////////////////////////////////
                            ERC20 OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function testTransfer() public {
        token.mint(address(1), 100 ether);
        hevm.prank(address(1));
        token.transfer(address(2), 100 ether);
        assertEq(token.balanceOf(address(1)), 0);
        assertEq(token.balanceOf(address(2)), 100 ether);
    }

    function testTransferFailed() public {
        testAttach();
        hevm.expectRevert(IERC20Boost.AttachedBoost.selector);
        token.transfer(address(2), 100 ether);
    }

    function testTransferFrom() public {
        token.mint(address(1), 100 ether);
        hevm.prank(address(1));
        token.approve(address(this), 100 ether);

        token.transferFrom(address(1), address(2), 100 ether);
        assertEq(token.balanceOf(address(1)), 0);
        assertEq(token.balanceOf(address(2)), 100 ether);
    }

    function testTransferFromFailed() public {
        testAttach();
        hevm.expectRevert(IERC20Boost.AttachedBoost.selector);
        hevm.prank(address(1));
        token.transferFrom(address(1), address(2), 100 ether);
    }

    function testBurn() public {
        token.mint(address(1), 100 ether);
        hevm.prank(address(1));
        token.burn(address(1), 100 ether);
        assertEq(token.balanceOf(address(1)), 0);
    }

    function testBurnFailed() public {
        testAttach();
        hevm.expectRevert(IERC20Boost.AttachedBoost.selector);
        hevm.prank(address(1));
        token.burn(address(1), 100 ether);
    }

    function testTransfer(uint256 amount) public {
        amount %= type(uint256).max - 100 ether;
        testAttach();
        token.mint(address(1), amount);
        hevm.prank(address(1));
        token.transfer(address(2), amount);
        assertEq(token.balanceOf(address(1)), 100 ether);
        assertEq(token.balanceOf(address(2)), amount);
    }

    /*///////////////////////////////////////////////////////////////
                        ADMIN GAUGE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function testAddGauge() public {
        token.addGauge(gauge1);
        require(token.gauges()[0] == gauge1, "gauge1 not added");
    }

    function testAddGaugeTwice() public {
        testAddGauge();
        token.addGauge(gauge2);
        require(token.gauges()[1] == gauge2, "gauge2 not added");
    }

    function testAddGaugeUnauthorized() public {
        hevm.prank(address(2));
        hevm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        token.addGauge(gauge1);
    }

    function testAddGaugeZeroAddress() public {
        hevm.expectRevert(abi.encodeWithSignature("InvalidGauge()"));
        token.addGauge(address(0));
    }

    function testAddGaugeAlreadyExists() public {
        testAddGauge();
        hevm.expectRevert(abi.encodeWithSignature("InvalidGauge()"));
        token.addGauge(gauge1);
    }

    function testRemoveGauge() public {
        testAddGauge();
        token.removeGauge(gauge1);
        require(token.deprecatedGauges()[0] == gauge1, "gauge1 not removed");
    }

    function testRemoveGaugeTwoGauges() public {
        testAddGaugeTwice();
        token.removeGauge(gauge1);
        token.removeGauge(gauge2);
        require(token.deprecatedGauges()[0] == gauge1, "gauge1 not removed");
        require(token.deprecatedGauges()[1] == gauge2, "gauge2 not removed");
    }

    function testRemoveGaugeUnauthorized() public {
        hevm.prank(address(2));
        hevm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        token.removeGauge(gauge1);
    }

    function testReplaceGauge() public {
        testAddGauge();
        token.replaceGauge(gauge1, gauge2);
        require(token.deprecatedGauges()[0] == gauge1, "gauge1 not removed");
        require(token.gauges()[1] == gauge2, "gauge1 not replaced");
    }

    /*///////////////////////////////////////////////////////////////
                            USER GAUGE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function testAttach() public {
        testAddGauge();
        token.mint(address(1), 100 ether);
        hevm.prank(gauge1);
        token.attach(address(1));
        require(token.userGauges(address(1))[0] == gauge1, "gauge1 not attached");
        (uint128 userBoost,) = token.getUserGaugeBoost(address(1), gauge1);
        require(userBoost == 100 ether, "unexpected boost");
    }

    function testAttachTwoGauges() public {
        testAddGaugeTwice();
        token.mint(address(1), 100 ether);
        hevm.prank(gauge1);
        token.attach(address(1));
        hevm.prank(gauge2);
        token.attach(address(1));
        require(token.userGauges(address(1))[0] == gauge1, "gauge1 not attached");
        require(token.userGauges(address(1))[1] == gauge2, "gauge2 not attached");
        (uint128 userBoost, uint128 totalBoost1) = token.getUserGaugeBoost(address(1), gauge1);
        (uint128 userBoost2, uint128 totalBoost2) = token.getUserGaugeBoost(address(1), gauge2);
        require(userBoost == 100 ether, "unexpected boost");
        require(userBoost2 == 100 ether, "unexpected boost");
        require(totalBoost1 == 100 ether, "unexpected total supply");
        require(totalBoost1 == totalBoost2, "unexpected total supply");
    }

    function testAttachTwoGaugesDifferentAmounts() public {
        testAddGaugeTwice();
        token.mint(address(1), 100 ether);
        hevm.prank(gauge1);
        token.attach(address(1));
        require(token.userGauges(address(1))[0] == gauge1, "gauge1 not attached");
        (uint128 userBoost, uint128 totalBoost1) = token.getUserGaugeBoost(address(1), gauge1);
        (uint128 userBoost2, uint128 totalBoost2) = token.getUserGaugeBoost(address(1), gauge2);
        require(userBoost == 100 ether, "unexpected boost");
        require(userBoost2 == 0, "unexpected boost");
        require(totalBoost1 == 100 ether, "unexpected total supply");
        require(totalBoost2 == 0, "unexpected total supply");

        token.mint(address(1), 100 ether);
        hevm.prank(gauge2);
        token.attach(address(1));
        require(token.userGauges(address(1))[1] == gauge2, "gauge2 not attached");
        (userBoost, totalBoost1) = token.getUserGaugeBoost(address(1), gauge1);
        (userBoost2, totalBoost2) = token.getUserGaugeBoost(address(1), gauge2);
        require(userBoost == 100 ether, "unexpected boost");
        require(userBoost2 == 200 ether, "unexpected boost");
        require(totalBoost1 == 100 ether, "unexpected total supply");
        require(totalBoost2 == 200 ether, "unexpected total supply");
    }

    function testAttachNotGauge() public {
        hevm.expectRevert(abi.encodeWithSignature("InvalidGauge()"));
        token.attach(address(1));
    }

    function testAttachDeprecatedGauge() public {
        testAddGauge();
        token.removeGauge(gauge1);
        hevm.expectRevert(abi.encodeWithSignature("InvalidGauge()"));
        hevm.prank(gauge1);
        token.attach(address(1));
    }

    function testAttachAlreadyAdded() public {
        testAttach();
        hevm.expectRevert(abi.encodeWithSignature("GaugeAlreadyAttached()"));
        hevm.prank(gauge1);
        token.attach(address(1));
    }

    function testDetach() public {
        testAttach();
        hevm.prank(gauge1);
        token.detach(address(1));
        require(token.userGauges(address(1)).length == 0, "gauge1 not detached");
    }

    function testUpdateUserBoost() public {
        testDetach();
        token.updateUserBoost(address(1));
        (uint128 newUserBoost,) = token.getUserGaugeBoost(address(1), gauge1);
        require(newUserBoost == 0, "userBoost not updated");
        require(token.getUserBoost(address(1)) == 0, "userBoost not updated");
    }

    function testUpdateUserBoostDeprecated() public {
        testAttach();
        token.removeGauge(gauge1);
        token.updateUserBoost(address(1));
        (uint128 userGaugeBoost,) = token.getUserGaugeBoost(address(1), gauge1);
        require(userGaugeBoost == 100 ether, "userBoost not updated");
        require(token.getUserBoost(address(1)) == 0, "userBoost not updated");
    }

    function testDecrementGaugeBoost() public {
        testAttach();
        hevm.prank(address(1));
        token.decrementGaugeBoost(gauge1, 10 ether);
        (uint128 newUserBoost,) = token.getUserGaugeBoost(address(1), gauge1);
        require(newUserBoost == 90 ether, "userBoost not updated");
        require(token.getUserBoost(address(1)) == 100 ether, "total userBoost doesn't match");
    }

    function testDecrementGaugeBoostMoreThanAttached() public {
        testAttach();
        hevm.prank(address(1));
        token.decrementGaugeBoost(gauge1, 110 ether);
        (uint128 newUserBoost,) = token.getUserGaugeBoost(address(1), gauge1);
        require(newUserBoost == 0 ether, "userBoost not updated");
        require(token.getUserBoost(address(1)) == 100 ether, "total userBoost doesn't match");
    }

    function testDecrementGaugeBoostRemove() public {
        testAttach();
        hevm.prank(address(1));
        token.decrementGaugeBoost(gauge1, 110 ether);
        (uint128 newUserBoost,) = token.getUserGaugeBoost(address(1), gauge1);
        require(newUserBoost == 0 ether, "userBoost not updated");
        require(token.getUserBoost(address(1)) == 100 ether, "total userBoost doesn't match");
    }

    function testDecrementGaugeAllBoost() public {
        testAttach();
        hevm.prank(address(1));
        token.decrementGaugeAllBoost(gauge1);
        (uint128 newUserBoost,) = token.getUserGaugeBoost(address(1), gauge1);
        require(newUserBoost == 0 ether, "userBoost not updated");
        require(token.getUserBoost(address(1)) == 100 ether, "total userBoost doesn't match");
    }

    function testDecrementAllGaugesBoost() public {
        testAttachTwoGauges();
        hevm.prank(address(1));
        token.decrementAllGaugesBoost(10 ether);
        (uint128 newUserBoost,) = token.getUserGaugeBoost(address(1), gauge1);
        (uint128 newUserBoost2,) = token.getUserGaugeBoost(address(1), gauge2);
        require(newUserBoost == 90 ether, "userBoost not updated");
        require(newUserBoost2 == 90 ether, "userBoost not updated");
        require(token.getUserBoost(address(1)) == 100 ether, "total userBoost doesn't match");
    }

    function testDecrementGaugesBoostIndexed() public {
        testAttachTwoGauges();
        hevm.prank(address(1));
        token.decrementGaugesBoostIndexed(10 ether, 1, 1);
        (uint128 newUserBoost,) = token.getUserGaugeBoost(address(1), gauge1);
        (uint128 newUserBoost2,) = token.getUserGaugeBoost(address(1), gauge2);
        require(newUserBoost == 100 ether, "userBoost not updated");
        require(newUserBoost2 == 90 ether, "userBoost not updated");
        require(token.getUserBoost(address(1)) == 100 ether, "total userBoost doesn't match");
    }

    function testDecrementGaugesBoostIndexedAll() public {
        testAttachTwoGauges();
        hevm.prank(address(1));
        token.decrementGaugesBoostIndexed(100 ether, 1, 1);
        (uint128 newUserBoost,) = token.getUserGaugeBoost(address(1), gauge1);
        (uint128 newUserBoost2,) = token.getUserGaugeBoost(address(1), gauge2);
        require(newUserBoost == 100 ether, "userBoost not updated");
        require(newUserBoost2 == 0 ether, "userBoost not updated");
        require(token.getUserBoost(address(1)) == 100 ether, "total userBoost doesn't match");
    }

    function testDecrementGaugesBoostIndexedDeprecatedGauge() public {
        testAttachTwoGauges();
        token.removeGauge(gauge1);
        hevm.prank(address(1));
        token.decrementGaugesBoostIndexed(10 ether, 1, 1);
        (uint128 newUserBoost,) = token.getUserGaugeBoost(address(1), gauge1);
        (uint128 newUserBoost2,) = token.getUserGaugeBoost(address(1), gauge2);
        require(newUserBoost == 100 ether, "userBoost not updated");
        require(newUserBoost2 == 90 ether, "userBoost not updated");
        require(token.getUserBoost(address(1)) == 100 ether, "total userBoost doesn't match");

        token.updateUserBoost(address(1));
        (newUserBoost,) = token.getUserGaugeBoost(address(1), gauge1);
        (newUserBoost2,) = token.getUserGaugeBoost(address(1), gauge2);
        require(newUserBoost == 100 ether, "userBoost not updated");
        require(newUserBoost2 == 90 ether, "userBoost not updated");
        require(token.getUserBoost(address(1)) == 90 ether, "userBoost not updated");
    }

    function testDecrementAllGaugesAllBoost() public {
        testAttachTwoGauges();
        hevm.prank(address(1));
        token.decrementAllGaugesAllBoost();
        (uint128 newUserBoost,) = token.getUserGaugeBoost(address(1), gauge1);
        (uint128 newUserBoost2,) = token.getUserGaugeBoost(address(1), gauge2);
        require(newUserBoost == 0, "userBoost not updated");
        require(newUserBoost2 == 0, "userBoost not updated");
        require(token.getUserBoost(address(1)) == 0 ether, "total userBoost doesn't match");
    }
}
