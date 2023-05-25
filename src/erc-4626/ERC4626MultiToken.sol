// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

import {IERC4626MultiToken} from "./interfaces/IERC4626MultiToken.sol";

/// @title Minimal ERC4626 tokenized Vault multi asset implementation
/// @author Maia DAO (https://github.com/Maia-DAO)
abstract contract ERC4626MultiToken is ERC20, ReentrancyGuard, IERC4626MultiToken {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC4626MultiToken
    address[] public assets;

    /// @inheritdoc IERC4626MultiToken
    uint256[] public weights;

    /// @inheritdoc IERC4626MultiToken
    mapping(address => uint256) public assetId;

    /// @inheritdoc IERC4626MultiToken
    uint256 public totalWeights;

    /// @inheritdoc IERC4626MultiToken
    function getAssets() external view returns (address[] memory) {
        return assets;
    }

    constructor(address[] memory _assets, uint256[] memory _weights, string memory _name, string memory _symbol)
        ERC20(_name, _symbol, 18)
    {
        assets = _assets;
        weights = _weights;

        uint256 length = _weights.length;
        uint256 _totalWeights;

        if (length != _assets.length || length == 0) revert InvalidLength();

        for (uint256 i = 0; i < length;) {
            require(ERC20(_assets[i]).decimals() == 18);
            require(_weights[i] > 0);

            _totalWeights += _weights[i];
            assetId[_assets[i]] = i + 1;

            emit AssetAdded(_assets[i], _weights[i]);

            unchecked {
                i++;
            }
        }
        totalWeights = _totalWeights;
    }

    function receiveAssets(uint256[] memory assetsAmounts) private {
        uint256 length = assetsAmounts.length;
        for (uint256 i = 0; i < length;) {
            assets[i].safeTransferFrom(msg.sender, address(this), assetsAmounts[i]);

            unchecked {
                i++;
            }
        }
    }

    function sendAssets(uint256[] memory assetsAmounts, address receiver) private {
        uint256 length = assetsAmounts.length;
        for (uint256 i = 0; i < length;) {
            assets[i].safeTransfer(receiver, assetsAmounts[i]);

            unchecked {
                i++;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC4626MultiToken
    function deposit(uint256[] calldata assetsAmounts, address receiver)
        public
        virtual
        nonReentrant
        returns (uint256 shares)
    {
        // Check for rounding error since we round down in previewDeposit.
        require((shares = previewDeposit(assetsAmounts)) != 0, "ZERO_SHARES");

        // Need to transfer before minting or ERC777s could reenter.
        receiveAssets(assetsAmounts);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assetsAmounts, shares);

        afterDeposit(assetsAmounts, shares);
    }

    /// @inheritdoc IERC4626MultiToken
    function mint(uint256 shares, address receiver)
        public
        virtual
        nonReentrant
        returns (uint256[] memory assetsAmounts)
    {
        assetsAmounts = previewMint(shares); // No need to check for rounding error, previewMint rounds up.

        // Need to transfer before minting or ERC777s could reenter.
        receiveAssets(assetsAmounts);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assetsAmounts, shares);

        afterDeposit(assetsAmounts, shares);
    }

    /// @inheritdoc IERC4626MultiToken
    function withdraw(uint256[] calldata assetsAmounts, address receiver, address owner)
        public
        virtual
        nonReentrant
        returns (uint256 shares)
    {
        shares = previewWithdraw(assetsAmounts); // No need to check for rounding error, previewWithdraw rounds up.

        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        beforeWithdraw(assetsAmounts, shares);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assetsAmounts, shares);

        sendAssets(assetsAmounts, receiver);
    }

    /// @inheritdoc IERC4626MultiToken
    function redeem(uint256 shares, address receiver, address owner)
        public
        virtual
        nonReentrant
        returns (uint256[] memory assetsAmounts)
    {
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        assetsAmounts = previewRedeem(shares);
        uint256 length = assetsAmounts.length;
        for (uint256 i = 0; i < length;) {
            // Check for rounding error since we round down in previewRedeem.
            if (assetsAmounts[i] == 0) revert ZeroAssets();
            unchecked {
                i++;
            }
        }

        beforeWithdraw(assetsAmounts, shares);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assetsAmounts, shares);

        sendAssets(assetsAmounts, receiver);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    function totalAssets() public view virtual returns (uint256);

    /// @inheritdoc IERC4626MultiToken
    function convertToShares(uint256[] calldata assetsAmounts) public view virtual returns (uint256 shares) {
        uint256 _totalWeights = totalWeights;
        uint256 length = assetsAmounts.length;

        if (length != assets.length) revert InvalidLength();

        shares = type(uint256).max;
        for (uint256 i = 0; i < length;) {
            uint256 share = assetsAmounts[i].mulDiv(_totalWeights, weights[i]);
            if (share < shares) shares = share;
            unchecked {
                i++;
            }
        }
    }

    /// @inheritdoc IERC4626MultiToken
    function convertToAssets(uint256 shares) public view virtual returns (uint256[] memory assetsAmounts) {
        uint256 _totalWeights = totalWeights;
        uint256 length = assets.length;

        assetsAmounts = new uint256[](length);
        for (uint256 i = 0; i < length;) {
            assetsAmounts[i] = shares.mulDiv(weights[i], _totalWeights);
            unchecked {
                i++;
            }
        }
    }

    /// @inheritdoc IERC4626MultiToken
    function previewDeposit(uint256[] calldata assetsAmounts) public view virtual returns (uint256) {
        return convertToShares(assetsAmounts);
    }

    /// @inheritdoc IERC4626MultiToken
    function previewMint(uint256 shares) public view virtual returns (uint256[] memory assetsAmounts) {
        uint256 _totalWeights = totalWeights;
        uint256 length = assets.length;

        assetsAmounts = new uint256[](length);
        for (uint256 i = 0; i < length;) {
            assetsAmounts[i] = shares.mulDivUp(weights[i], _totalWeights);
            unchecked {
                i++;
            }
        }
    }

    /// @inheritdoc IERC4626MultiToken
    function previewWithdraw(uint256[] calldata assetsAmounts) public view virtual returns (uint256 shares) {
        uint256 _totalWeights = totalWeights;
        uint256 length = assetsAmounts.length;

        if (length != assets.length) revert InvalidLength();

        for (uint256 i = 0; i < length;) {
            uint256 share = assetsAmounts[i].mulDivUp(_totalWeights, weights[i]);
            if (share > shares) shares = share;
            unchecked {
                i++;
            }
        }
    }

    /// @inheritdoc IERC4626MultiToken
    function previewRedeem(uint256 shares) public view virtual returns (uint256[] memory) {
        return convertToAssets(shares);
    }

    /*//////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC4626MultiToken
    function maxDeposit(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    /// @inheritdoc IERC4626MultiToken
    function maxMint(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    /// @inheritdoc IERC4626MultiToken
    function maxWithdraw(address owner) public view virtual returns (uint256[] memory) {
        return convertToAssets(balanceOf[owner]);
    }

    /// @inheritdoc IERC4626MultiToken
    function maxRedeem(address owner) public view virtual returns (uint256) {
        return balanceOf[owner];
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/

    function beforeWithdraw(uint256[] memory assetsAmounts, uint256 shares) internal virtual {}

    function afterDeposit(uint256[] memory assetsAmounts, uint256 shares) internal virtual {}
}
