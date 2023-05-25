// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "../helpers/UlyssesTokenProp.t.sol";

abstract contract UlyssesTokenHandler is UlyssesTokenProp {
    function setUp() public virtual;

    uint256 constant NUM_USERS = 4;
    uint256 constant NUM_ASSETS = 4;

    struct Init {
        address[NUM_USERS] user;
        uint256[NUM_USERS][NUM_ASSETS] share;
        uint256[NUM_USERS][NUM_ASSETS] asset;
        int256 yield;
    }

    uint256[] _shares;
    uint256[] _assets;

    // setup initial vault state as follows:
    //
    // totalAssets == sum(init.share) + init.yield
    // totalShares == sum(init.share)
    //
    // init.user[i]'s assets == init.asset[i]
    // init.user[i]'s shares == init.share[i]
    function setUpVault(Init memory init) public virtual {
        // setup initial shares and assets for individual users
        for (uint256 i = 0; i < NUM_USERS; i++) {
            address user = init.user[i];
            vm.assume(_isEOA(user));
            // shares
            _shares = init.share[i];
            _mint_amounts(user, _underlyings_, _shares);

            _approve(_underlyings_, user, _vault_, _shares);
            vm.prank(user);
            try UlyssesToken(_vault_).deposit(_shares, user) {}
            catch {
                vm.assume(false);
            }
            // assets
            _assets = init.asset[i];
            _mint_amounts(user, _underlyings_, _assets);
        }

        // setup initial yield for vault
        setUpYield(init);
    }

    // setup initial yield
    function setUpYield(Init memory init) public virtual {
        if (init.yield >= 0) {
            // gain
            uint256 gain = uint256(init.yield);
            _mints_amount(_vault_, _underlyings_, gain);
        } else {
            // loss
            vm.assume(init.yield > type(int256).min); // avoid overflow in conversion
            uint256 loss = uint256(-1 * init.yield);
            _mints_amount(_vault_, _underlyings_, loss);
        }
    }

    function _mint_amounts(address user, address[] memory assets, uint256[] memory amounts) public virtual {
        for (uint256 i = 0; i < assets.length; i++) {
            _mint(user, assets[i], amounts[i]);
        }
    }

    function _mints_amount(address user, address[] memory assets, uint256 amount) public virtual {
        for (uint256 i = 0; i < assets.length; i++) {
            _mint(user, assets[i], amount);
        }
    }

    function _mint(address user, address asset, uint256 amount) public virtual {
        try MockERC20(asset).mint(user, amount) {}
        catch {
            vm.assume(false);
        }
    }

    //
    // asset
    //
    function test_asset(Init memory init) public virtual {
        setUpVault(init);
        address caller = init.user[0];
        prop_asset(caller);
    }

    function test_totalAssets(Init memory init) public virtual {
        setUpVault(init);
        address caller = init.user[0];
        prop_totalAssets(caller);
    }

    //
    // convert
    //
    function test_convertToShares(Init memory init, uint256[NUM_ASSETS] memory assets) public virtual {
        setUpVault(init);
        address caller1 = init.user[0];
        address caller2 = init.user[1];
        uint256[] memory assetsForAction = new uint256[](NUM_ASSETS);
        for (uint256 i = 0; i < NUM_ASSETS; i++) {
            assetsForAction[i] = assets[i];
        }
        prop_convertToShares(caller1, caller2, assetsForAction);
    }

    function test_convertToAssets(Init memory init, uint256 shares) public virtual {
        setUpVault(init);
        address caller1 = init.user[0];
        address caller2 = init.user[1];
        prop_convertToAssets(caller1, caller2, shares);
    }

    //
    // deposit
    //
    function test_maxDeposit(Init memory init) public virtual {
        setUpVault(init);
        address caller = init.user[0];
        address receiver = init.user[1];
        prop_maxDeposit(caller, receiver);
    }

    function test_previewDeposit(Init memory init, uint256[NUM_ASSETS] memory assets) public virtual {
        setUpVault(init);
        address caller = init.user[0];
        address receiver = init.user[1];
        address other = init.user[2];

        uint256[] memory maxAssets = _max_deposit(caller);
        uint256[] memory assetsForAction = new uint256[](NUM_ASSETS);
        for (uint256 i = 0; i < NUM_ASSETS; i++) {
            assetsForAction[i] = bound(assets[i], 0, maxAssets[i]);
        }

        _approve(_underlyings_, caller, _vault_, type(uint256).max);
        prop_previewDeposit(caller, receiver, other, assetsForAction);
    }

    function test_deposit(Init memory init, uint256[NUM_ASSETS] memory assets, uint256 allowance) public virtual {
        setUpVault(init);
        address caller = init.user[0];
        address receiver = init.user[1];

        uint256[] memory maxAssets = _max_deposit(caller);
        uint256[] memory assetsForAction = new uint256[](NUM_ASSETS);
        for (uint256 i = 0; i < NUM_ASSETS; i++) {
            assetsForAction[i] = bound(assets[i], 0, maxAssets[i]);
        }

        _approve(_underlyings_, caller, _vault_, allowance);
        prop_deposit(caller, receiver, assetsForAction);
    }

    //
    // mint
    //
    function test_maxMint(Init memory init) public virtual {
        setUpVault(init);
        address caller = init.user[0];
        address receiver = init.user[1];
        prop_maxMint(caller, receiver);
    }

    function test_previewMint(Init memory init, uint256 shares) public virtual {
        setUpVault(init);
        address caller = init.user[0];
        address receiver = init.user[1];
        address other = init.user[2];
        shares = bound(shares, 0, _max_mint(caller));
        _approve(_underlyings_, caller, _vault_, type(uint256).max);
        prop_previewMint(caller, receiver, other, shares);
    }

    function test_mint(Init memory init, uint256 shares, uint256 allowance) public virtual {
        setUpVault(init);
        address caller = init.user[0];
        address receiver = init.user[1];
        shares = bound(shares, 0, _max_mint(caller));
        _approve(_underlyings_, caller, _vault_, allowance);
        prop_mint(caller, receiver, shares);
    }

    //
    // withdraw
    //
    function test_maxWithdraw(Init memory init) public virtual {
        setUpVault(init);
        address caller = init.user[0];
        address owner = init.user[1];
        prop_maxWithdraw(caller, owner);
    }

    function test_previewWithdraw(Init memory init, uint256[NUM_ASSETS] memory assets) public virtual {
        setUpVault(init);
        address caller = init.user[0];
        address receiver = init.user[1];
        address owner = init.user[2];
        address other = init.user[3];

        uint256[] memory maxAssets = _max_withdraw(owner);
        uint256[] memory assetsForAction = new uint256[](NUM_ASSETS);
        for (uint256 i = 0; i < NUM_ASSETS; i++) {
            assetsForAction[i] = bound(assets[i], 0, maxAssets[i]);
        }

        _approve(_vault_, owner, caller, type(uint256).max);
        prop_previewWithdraw(caller, receiver, owner, other, assetsForAction);
    }

    function test_withdraw(Init memory init, uint256[NUM_ASSETS] memory assets, uint256 allowance) public virtual {
        setUpVault(init);
        address caller = init.user[0];
        address receiver = init.user[1];
        address owner = init.user[2];

        uint256[] memory maxAssets = _max_withdraw(owner);
        uint256[] memory assetsForAction = new uint256[](NUM_ASSETS);
        for (uint256 i = 0; i < NUM_ASSETS; i++) {
            assetsForAction[i] = bound(assets[i], 0, maxAssets[i]);
        }

        _approve(_vault_, owner, caller, allowance);
        prop_withdraw(caller, receiver, owner, assetsForAction);
    }

    function testFail_withdraw(Init memory init, uint256[NUM_ASSETS] memory assets) public virtual {
        setUpVault(init);
        address caller = init.user[0];
        address receiver = init.user[1];
        address owner = init.user[2];

        uint256[] memory maxAssets = _max_withdraw(owner);
        uint256[] memory assetsForAction = new uint256[](NUM_ASSETS);
        for (uint256 i = 0; i < NUM_ASSETS; i++) {
            assetsForAction[i] = bound(assets[i], 0, maxAssets[i]);
        }

        vm.assume(caller != owner);
        for (uint256 i = 0; i < assetsForAction.length; i++) {
            vm.assume(assetsForAction[i] > 0);
        }

        _approve(_vault_, owner, caller, 0);
        vm.prank(caller);
        uint256 shares = UlyssesToken(_vault_).withdraw(assetsForAction, receiver, owner);
        assertGt(shares, 0); // this assert is expected to fail
    }

    //
    // redeem
    //
    function test_maxRedeem(Init memory init) public virtual {
        setUpVault(init);
        address caller = init.user[0];
        address owner = init.user[1];
        prop_maxRedeem(caller, owner);
    }

    function test_previewRedeem(Init memory init, uint256 shares) public virtual {
        setUpVault(init);
        address caller = init.user[0];
        address receiver = init.user[1];
        address owner = init.user[2];
        address other = init.user[3];
        shares = bound(shares, 0, _max_redeem(owner));
        _approve(_vault_, owner, caller, type(uint256).max);
        prop_previewRedeem(caller, receiver, owner, other, shares);
    }

    function test_redeem(Init memory init, uint256 shares, uint256 allowance) public virtual {
        setUpVault(init);
        address caller = init.user[0];
        address receiver = init.user[1];
        address owner = init.user[2];
        shares = bound(shares, 0, _max_redeem(owner));
        _approve(_vault_, owner, caller, allowance);
        prop_redeem(caller, receiver, owner, shares);
    }

    function testFail_redeem(Init memory init, uint256 shares) public virtual {
        setUpVault(init);
        address caller = init.user[0];
        address receiver = init.user[1];
        address owner = init.user[2];
        shares = bound(shares, 0, _max_redeem(owner));
        vm.assume(caller != owner);
        vm.assume(shares > 0);
        _approve(_vault_, owner, caller, 0);
        vm.prank(caller);
        UlyssesToken(_vault_).redeem(shares, receiver, owner);
    }

    //
    // round trip tests
    //
    function test_RT_deposit_redeem(Init memory init, uint256[NUM_ASSETS] memory assets) public virtual {
        setUpVault(init);
        address caller = init.user[0];

        uint256[] memory maxAssets = _max_deposit(caller);
        uint256[] memory assetsForAction = new uint256[](NUM_ASSETS);
        for (uint256 i = 0; i < NUM_ASSETS; i++) {
            assetsForAction[i] = bound(assets[i], 0, maxAssets[i]);
        }

        _approve(_underlyings_, caller, _vault_, type(uint256).max);
        prop_RT_deposit_redeem(caller, assetsForAction);
    }

    function test_RT_deposit_withdraw(Init memory init, uint256[NUM_ASSETS] memory assets) public virtual {
        setUpVault(init);
        address caller = init.user[0];

        uint256[] memory maxAssets = _max_deposit(caller);
        uint256[] memory assetsForAction = new uint256[](NUM_ASSETS);
        for (uint256 i = 0; i < NUM_ASSETS; i++) {
            assetsForAction[i] = bound(assets[i], 0, maxAssets[i]);
        }

        _approve(_underlyings_, caller, _vault_, type(uint256).max);
        prop_RT_deposit_withdraw(caller, assetsForAction);
    }

    function test_RT_redeem_deposit(Init memory init, uint256 shares) public virtual {
        setUpVault(init);
        address caller = init.user[0];
        shares = bound(shares, 0, _max_redeem(caller));
        _approve(_underlyings_, caller, _vault_, type(uint256).max);
        prop_RT_redeem_deposit(caller, shares);
    }

    function test_RT_redeem_mint(Init memory init, uint256 shares) public virtual {
        setUpVault(init);
        address caller = init.user[0];
        shares = bound(shares, 0, _max_redeem(caller));
        _approve(_underlyings_, caller, _vault_, type(uint256).max);
        prop_RT_redeem_mint(caller, shares);
    }

    function test_RT_mint_withdraw(Init memory init, uint256 shares) public virtual {
        setUpVault(init);
        address caller = init.user[0];
        shares = bound(shares, 0, _max_mint(caller));
        _approve(_underlyings_, caller, _vault_, type(uint256).max);
        prop_RT_mint_withdraw(caller, shares);
    }

    function test_RT_mint_redeem(Init memory init, uint256 shares) public virtual {
        setUpVault(init);
        address caller = init.user[0];
        shares = bound(shares, 0, _max_mint(caller));
        _approve(_underlyings_, caller, _vault_, type(uint256).max);
        prop_RT_mint_redeem(caller, shares);
    }

    function test_RT_withdraw_mint(Init memory init, uint256[NUM_ASSETS] memory assets) public virtual {
        setUpVault(init);
        address caller = init.user[0];

        uint256[] memory maxAssets = _max_withdraw(caller);
        uint256[] memory assetsForAction = new uint256[](NUM_ASSETS);
        for (uint256 i = 0; i < NUM_ASSETS; i++) {
            assetsForAction[i] = bound(assets[i], 0, maxAssets[i]);
        }

        _approve(_underlyings_, caller, _vault_, type(uint256).max);
        prop_RT_withdraw_mint(caller, assetsForAction);
    }

    function test_RT_withdraw_deposit(Init memory init, uint256[NUM_ASSETS] memory assets) public virtual {
        setUpVault(init);
        address caller = init.user[0];

        uint256[] memory maxAssets = _max_withdraw(caller);
        uint256[] memory assetsForAction = new uint256[](NUM_ASSETS);
        for (uint256 i = 0; i < NUM_ASSETS; i++) {
            assetsForAction[i] = bound(assets[i], 0, maxAssets[i]);
        }
        _approve(_underlyings_, caller, _vault_, type(uint256).max);
        prop_RT_withdraw_deposit(caller, assetsForAction);
    }

    //
    // utils
    //
    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function _isEOA(address account) internal view returns (bool) {
        return account.code.length == 0;
    }

    function _approve(address[] memory tokens, address owner, address spender, uint256 amount) internal {
        for (uint256 i = 0; i < tokens.length; i++) {
            _approve(tokens[i], owner, spender, amount);
        }
    }

    function _approve(address[] memory tokens, address owner, address spender, uint256[] memory amount) internal {
        for (uint256 i = 0; i < tokens.length; i++) {
            _approve(tokens[i], owner, spender, amount[i]);
        }
    }

    function _approve(address token, address owner, address spender, uint256 amount) internal {
        vm.prank(owner);
        _safeApprove(token, spender, 0);
        vm.prank(owner);
        _safeApprove(token, spender, amount);
    }

    function _safeApprove(address token, address spender, uint256 amount) internal {
        (bool success, bytes memory retdata) =
            token.call(abi.encodeWithSelector(ERC20.approve.selector, spender, amount));
        vm.assume(success);
        if (retdata.length > 0) vm.assume(abi.decode(retdata, (bool)));
    }

    function _max_deposit(address from) internal virtual returns (uint256[] memory maxAssets) {
        maxAssets = new uint[](_underlyings_.length);
        if (_unlimitedAmount) {
            for (uint256 i = 0; i < _underlyings_.length; i++) {
                maxAssets[i] = type(uint256).max;
            }
        } else {
            for (uint256 i = 0; i < _underlyings_.length; i++) {
                maxAssets[i] = MockERC20(_underlyings_[i]).balanceOf(from);
            }
        }
    }

    function _max_mint(address from) internal virtual returns (uint256) {
        if (_unlimitedAmount) return type(uint256).max;
        uint256[] memory maxAssets = new uint[](_underlyings_.length);
        for (uint256 i = 0; i < _underlyings_.length; i++) {
            maxAssets[i] = MockERC20(_underlyings_[i]).balanceOf(from);
        }
        return vault_convertToShares(maxAssets);
    }

    function _max_withdraw(address from) internal virtual returns (uint256[] memory) {
        if (_unlimitedAmount) {
            uint256[] memory maxAssets = new uint[](_underlyings_.length);
            for (uint256 i = 0; i < _underlyings_.length; i++) {
                maxAssets[i] = type(uint256).max;
            }
            return maxAssets;
        }

        return vault_convertToAssets(MockERC20(_vault_).balanceOf(from)); // may be different from maxWithdraw(from)
    }

    function _max_redeem(address from) internal virtual returns (uint256) {
        if (_unlimitedAmount) return type(uint256).max;
        return MockERC20(_vault_).balanceOf(from); // may be different from maxRedeem(from)
    }
}
