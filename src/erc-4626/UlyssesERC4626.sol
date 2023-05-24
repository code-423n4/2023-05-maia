// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

import {IUlyssesERC4626} from "./interfaces/IUlyssesERC4626.sol";

/// @title Minimal ERC4626 tokenized 1:1 Vault implementation
/// @author Maia DAO (https://github.com/Maia-DAO)
abstract contract UlyssesERC4626 is ERC20, ReentrancyGuard, IUlyssesERC4626 {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    address public immutable asset;

    constructor(address _asset, string memory _name, string memory _symbol) ERC20(_name, _symbol, 18) {
        asset = _asset;

        if (ERC20(_asset).decimals() != 18) revert InvalidAssetDecimals();
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 assets, address receiver) public virtual nonReentrant returns (uint256 shares) {
        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        shares = beforeDeposit(assets);

        require(shares != 0, "ZERO_SHARES");

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function mint(uint256 shares, address receiver) public virtual nonReentrant returns (uint256 assets) {
        assets = beforeMint(shares); // No need to check for rounding error, previewMint rounds up.

        require(assets != 0, "ZERO_ASSETS");

        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function redeem(uint256 shares, address receiver, address owner)
        public
        virtual
        nonReentrant
        returns (uint256 assets)
    {
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        _burn(owner, shares);

        assets = afterRedeem(shares);

        require(assets != 0, "ZERO_ASSETS");

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    function totalAssets() public view virtual returns (uint256);

    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        return assets;
    }

    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        return shares;
    }

    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return assets;
    }

    function previewMint(uint256 shares) public view virtual returns (uint256) {
        return shares;
    }

    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return shares;
    }

    /*//////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    function maxDeposit(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxRedeem(address owner) public view virtual returns (uint256) {
        return balanceOf[owner];
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Should not do any external calls to prevent reentrancy.
    function beforeDeposit(uint256 assets) internal virtual returns (uint256 shares);

    /// @dev Should not do any external calls to prevent reentrancy.
    function beforeMint(uint256 shares) internal virtual returns (uint256 assets);

    /// @dev Should not do any external calls to prevent reentrancy.
    function afterRedeem(uint256 shares) internal virtual returns (uint256 assets);
}
