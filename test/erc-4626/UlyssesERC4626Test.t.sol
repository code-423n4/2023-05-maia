// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {MockUlyssesERC4626} from "./mocks/MockUlyssesERC4626.t.sol";

contract UlyssesERC4626Test is DSTestPlus {
    MockERC20 underlying;
    MockUlyssesERC4626 vault;

    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);
        vault = new MockUlyssesERC4626(address(underlying), "Mock Token Vault", "vwTKN");
    }

    function invariantMetadata() public {
        assertEq(vault.name(), "Mock Token Vault");
        assertEq(vault.symbol(), "vwTKN");
        assertEq(vault.decimals(), 18);
    }

    function testMetadata(string calldata name, string calldata symbol) public {
        MockUlyssesERC4626 vlt = new MockUlyssesERC4626(address(underlying), name, symbol);
        assertEq(vlt.name(), name);
        assertEq(vlt.symbol(), symbol);
        assertEq(address(vlt.asset()), address(underlying));
    }

    function testSingleDeposit(uint128 amount) public {
        if (amount == 0) amount = 1;

        uint256 aliceUnderlyingAmount = amount;

        address alice = address(0xABCD);

        underlying.mint(alice, aliceUnderlyingAmount);

        hevm.prank(alice);
        underlying.approve(address(vault), aliceUnderlyingAmount);
        assertEq(underlying.allowance(alice, address(vault)), aliceUnderlyingAmount);

        uint256 alicePreDepositBal = underlying.balanceOf(alice);

        hevm.prank(alice);
        uint256 aliceShareAmount = vault.deposit(aliceUnderlyingAmount, alice);

        assertEq(vault.afterDepositHookCalledCounter(), 1);

        // Expect exchange rate to be 1:1 on initial deposit.
        assertEq(aliceUnderlyingAmount, aliceShareAmount);
        assertEq(vault.previewRedeem(aliceShareAmount), aliceUnderlyingAmount);
        assertEq(vault.previewDeposit(aliceUnderlyingAmount), aliceShareAmount);
        assertEq(vault.totalSupply(), aliceShareAmount);
        assertEq(vault.totalAssets(), aliceUnderlyingAmount);
        assertEq(vault.balanceOf(alice), aliceShareAmount);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), aliceUnderlyingAmount);
        assertEq(underlying.balanceOf(alice), alicePreDepositBal - aliceUnderlyingAmount);
    }

    function testSingleMintRedeem(uint128 amount) public {
        if (amount == 0) amount = 1;

        uint256 aliceShareAmount = amount;

        address alice = address(0xABCD);

        underlying.mint(alice, aliceShareAmount);

        hevm.prank(alice);
        underlying.approve(address(vault), aliceShareAmount);
        assertEq(underlying.allowance(alice, address(vault)), aliceShareAmount);

        uint256 alicePreDepositBal = underlying.balanceOf(alice);

        hevm.prank(alice);
        uint256 aliceUnderlyingAmount = vault.mint(aliceShareAmount, alice);

        assertEq(vault.afterDepositHookCalledCounter(), 1);

        // Expect exchange rate to be 1:1 on initial mint.
        assertEq(aliceShareAmount, aliceUnderlyingAmount);
        assertEq(vault.previewRedeem(aliceShareAmount), aliceUnderlyingAmount);
        assertEq(vault.previewDeposit(aliceUnderlyingAmount), aliceShareAmount);
        assertEq(vault.totalSupply(), aliceShareAmount);
        assertEq(vault.totalAssets(), aliceUnderlyingAmount);
        assertEq(vault.balanceOf(alice), aliceUnderlyingAmount);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), aliceUnderlyingAmount);
        assertEq(underlying.balanceOf(alice), alicePreDepositBal - aliceUnderlyingAmount);

        hevm.prank(alice);
        vault.redeem(aliceShareAmount, alice, alice);

        assertEq(vault.beforeWithdrawHookCalledCounter(), 1);

        assertEq(vault.totalAssets(), 0);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 0);
        assertEq(underlying.balanceOf(alice), alicePreDepositBal);
    }

    function testMultipleMintDepositRedeemWithdraw() public {
        // Scenario:
        // A = Alice, B = Bob, V = Vault
        // (Vault Shares == Vault Assets)
        //  ________________________________________________________________
        // | V shares | A share | A assets | B share | B assets | V balance |
        // |================================================================|
        // | 1. Alice mints 2000 shares (costs 2000 tokens)                 |
        // |----------|---------|----------|---------|----------|-----------|
        // |     2000 |    2000 |     2000 |       0 |        0 |      2000 |
        // |----------|---------|----------|---------|----------|-----------|
        // | 2. Bob deposits 4000 tokens (mints 4000 shares)                |
        // |----------|---------|----------|---------|----------|-----------|
        // |     6000 |    2000 |     2000 |    4000 |     4000 |      6000 |
        // |----------|---------|----------|---------|----------|-----------|
        // | 3. Vault is sent 3000 tokens...                                |
        // |----------|---------|----------|---------|----------|-----------|
        // |     6000 |    2000 |     2000 |    4000 |     4000 |      9000 |
        // |----------|---------|----------|---------|----------|-----------|
        // | 4. Alice deposits 2000 tokens (mints 2000 shares)              |
        // |----------|---------|----------|---------|----------|-----------|
        // |     8000 |    4000 |     4000 |    4000 |     4000 |     11000 |
        // |----------|---------|----------|---------|----------|-----------|
        // | 5. Bob mints 2000 shares (costs 2000 assets)                   |
        // |----------|---------|----------|---------|----------|-----------|
        // |    10000 |    4000 |     4000 |    6000 |     6000 |     13000 |
        // |----------|---------|----------|---------|----------|-----------|
        // | 6. Vault is sent 3000 tokens...                                |
        // |----------|---------|----------|---------|----------|-----------|
        // |    10000 |    4000 |     4000 |    6000 |     6000 |     16000 |
        // |----------|---------|----------|---------|----------|-----------|
        // | 7. Alice redeem 1333 shares (1333 assets)                      |
        // |----------|---------|----------|---------|----------|-----------|
        // |     8667 |    2667 |     2667 |    6000 |     6000 |     14667 |
        // |----------|---------|----------|---------|----------|-----------|
        // | 8. Bob redeems 1608 assets (1608 shares)                     |
        // |----------|---------|----------|---------|----------|-----------|
        // |     7059 |    2667 |     2667 |    4392 |     4392 |     13059 |
        // |----------|---------|----------|---------|----------|-----------|
        // | 9. Alice redeems 2667 assets (2667 shares)                   |
        // |----------|---------|----------|---------|----------|-----------|
        // |     4392 |       0 |        0 |    4392 |     4392 |     10392 |
        // |----------|---------|----------|---------|----------|-----------|
        // | 10. Bob redeem 4392 shares (4392 tokens)                       |
        // |----------|---------|----------|---------|----------|-----------|
        // |        0 |       0 |        0 |       0 |        0 |      6000 |
        // |__________|_________|__________|_________|__________|___________|

        address alice = address(0xABCD);
        address bob = address(0xDCBA);

        uint256 mutationUnderlyingAmount = 3000;

        underlying.mint(alice, 4000);

        hevm.prank(alice);
        underlying.approve(address(vault), 4000);

        assertEq(underlying.allowance(alice, address(vault)), 4000);

        underlying.mint(bob, 6000);

        hevm.prank(bob);
        underlying.approve(address(vault), 6000);

        assertEq(underlying.allowance(bob, address(vault)), 6000);

        // 1. Alice mints 2000 shares (costs 2000 tokens)
        hevm.prank(alice);
        uint256 aliceUnderlyingAmount = vault.mint(2000, alice);

        uint256 aliceShareAmount = vault.previewDeposit(aliceUnderlyingAmount);
        // assertEq(vault.afterDepositHookCalledCounter(), 1);

        // Expect to have received the requested mint amount.
        assertEq(aliceShareAmount, 2000);
        assertEq(vault.balanceOf(alice), aliceShareAmount);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), aliceUnderlyingAmount);
        assertEq(vault.convertToShares(aliceUnderlyingAmount), vault.balanceOf(alice));

        // Expect a 1:1 ratio before mutation.
        assertEq(aliceUnderlyingAmount, 2000);

        // Sanity check.
        assertEq(vault.totalSupply(), aliceShareAmount);
        assertEq(vault.totalAssets(), aliceUnderlyingAmount);

        // 2. Bob deposits 4000 tokens (mints 4000 shares)
        hevm.prank(bob);
        uint256 bobShareAmount = vault.deposit(4000, bob);
        uint256 bobUnderlyingAmount = vault.previewRedeem(bobShareAmount);
        // assertEq(vault.afterDepositHookCalledCounter(), 2);

        // Expect to have received the requested underlying amount.
        assertEq(bobUnderlyingAmount, 4000);
        assertEq(vault.balanceOf(bob), bobShareAmount);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), bobUnderlyingAmount);
        assertEq(vault.convertToShares(bobUnderlyingAmount), vault.balanceOf(bob));

        // Expect a 1:1 ratio before mutation.
        assertEq(bobShareAmount, bobUnderlyingAmount);

        // Sanity check.
        uint256 preMutationShareBal = aliceShareAmount + bobShareAmount;
        uint256 preMutationBal = aliceUnderlyingAmount + bobUnderlyingAmount;
        assertEq(vault.totalSupply(), preMutationShareBal);
        assertEq(vault.totalAssets(), preMutationBal);
        assertEq(vault.totalSupply(), 6000);
        assertEq(vault.totalAssets(), 6000);

        // 3. Vault is sent 3000 tokens...
        // The Vault now contains more tokens, but the deposited exchange rate does not change.
        // Alice share is 33.33% of the Vault, Bob 66.66% of the Vault.
        // Alice's share count stays the same at 2000.
        // Bob's share count stays the same at 4000.
        underlying.mint(address(vault), mutationUnderlyingAmount);
        assertEq(vault.totalSupply(), preMutationShareBal);
        // Should not change.
        assertEq(vault.totalAssets(), preMutationShareBal);
        assertEq(vault.balanceOf(alice), aliceShareAmount);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), aliceUnderlyingAmount);
        assertEq(vault.balanceOf(bob), bobShareAmount);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), bobUnderlyingAmount);

        // 4. Alice deposits 2000 tokens (mints 2000 shares)
        hevm.prank(alice);
        vault.deposit(2000, alice);

        assertEq(vault.totalSupply(), 8000);
        assertEq(vault.balanceOf(alice), 4000);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 4000);
        assertEq(vault.balanceOf(bob), 4000);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 4000);

        // 5. Bob mints 2000 shares (costs 2000 assets)
        hevm.prank(bob);
        vault.mint(2000, bob);

        assertEq(vault.totalSupply(), 10000);
        assertEq(vault.balanceOf(alice), 4000);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 4000);
        assertEq(vault.balanceOf(bob), 6000);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 6000);

        // Sanity checks:
        // Alice and bob should have spent all their tokens now
        assertEq(underlying.balanceOf(alice), 0);
        assertEq(underlying.balanceOf(bob), 0);
        // Assets in vault: 4k (alice) + 6k (bob)
        assertEq(vault.totalAssets(), 10000);

        // 6. Vault is sent 3000 tokens
        underlying.mint(address(vault), mutationUnderlyingAmount);
        assertEq(vault.totalAssets(), 10000);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 4000);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 6000);

        // 7. Alice redeem 1333 shares (1333 assets)
        hevm.prank(alice);
        vault.redeem(1333, alice, alice);

        assertEq(underlying.balanceOf(alice), 1333);
        assertEq(vault.totalSupply(), 8667);
        assertEq(vault.totalAssets(), 8667);
        assertEq(vault.balanceOf(alice), 2667);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 2667);
        assertEq(vault.balanceOf(bob), 6000);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 6000);

        // 8. Bob redeems 1608 assets (1608 shares)
        hevm.prank(bob);
        vault.redeem(1608, bob, bob);

        assertEq(underlying.balanceOf(bob), 1608);
        assertEq(vault.totalSupply(), 7059);
        assertEq(vault.totalAssets(), 7059);
        assertEq(vault.balanceOf(alice), 2667);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 2667);
        assertEq(vault.balanceOf(bob), 4392);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 4392);

        // 9. Alice redeems 2667 assets (2667 shares)
        hevm.prank(alice);
        vault.redeem(2667, alice, alice);

        assertEq(underlying.balanceOf(alice), 4000);
        assertEq(vault.totalSupply(), 4392);
        assertEq(vault.totalAssets(), 4392);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 0);
        assertEq(vault.balanceOf(bob), 4392);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 4392);

        // 10. Bob redeem 4392 shares (4392 tokens)
        hevm.prank(bob);
        vault.redeem(4392, bob, bob);
        assertEq(underlying.balanceOf(bob), 6000);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 0);
        assertEq(vault.balanceOf(bob), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 0);

        // Sanity check, holds all extra sent tokens (did not affect pool)
        assertEq(underlying.balanceOf(address(vault)), 6000);
    }

    function testFailDepositWithNotEnoughApproval() public {
        underlying.mint(address(this), 0.5e18);
        underlying.approve(address(vault), 0.5e18);
        assertEq(underlying.allowance(address(this), address(vault)), 0.5e18);

        vault.deposit(1e18, address(this));
    }

    function testFailRedeemWithNotEnoughShareAmount() public {
        underlying.mint(address(this), 0.5e18);
        underlying.approve(address(vault), 0.5e18);

        vault.deposit(0.5e18, address(this));

        vault.redeem(1e18, address(this), address(this));
    }

    function testFailRedeemWithNoShareAmount() public {
        vault.redeem(1e18, address(this), address(this));
    }

    function testFailDepositWithNoApproval() public {
        vault.deposit(1e18, address(this));
    }

    function testFailMintWithNoApproval() public {
        vault.mint(1e18, address(this));
    }

    function testFailDepositZero() public {
        vault.deposit(0, address(this));
    }

    function testMintZero() public {
        hevm.expectRevert("ZERO_ASSETS");
        vault.mint(0, address(this));

        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 0);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalAssets(), 0);
    }

    function testFailRedeemZero() public {
        vault.redeem(0, address(this), address(this));
    }

    function testVaultInteractionsForSomeoneElse() public {
        // init 2 users with a 1e18 balance
        address alice = address(0xABCD);
        address bob = address(0xDCBA);
        underlying.mint(alice, 1e18);
        underlying.mint(bob, 1e18);

        hevm.prank(alice);
        underlying.approve(address(vault), 1e18);

        hevm.prank(bob);
        underlying.approve(address(vault), 1e18);

        // alice deposits 1e18 for bob
        hevm.prank(alice);
        vault.deposit(1e18, bob);

        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.balanceOf(bob), 1e18);
        assertEq(underlying.balanceOf(alice), 0);

        // bob mint 1e18 for alice
        hevm.prank(bob);
        vault.mint(1e18, alice);
        assertEq(vault.balanceOf(alice), 1e18);
        assertEq(vault.balanceOf(bob), 1e18);
        assertEq(underlying.balanceOf(bob), 0);

        // alice redeem 1e18 for bob
        hevm.prank(alice);
        vault.redeem(1e18, bob, alice);

        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.balanceOf(bob), 1e18);
        assertEq(underlying.balanceOf(bob), 1e18);
    }
}
