// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {ERC4626MultiToken, IERC4626MultiToken} from "@ERC4626/ERC4626MultiToken.sol";

import {IUlyssesToken} from "./interfaces/IUlyssesToken.sol";

/// @title Ulysses Token - tokenized Vault multi asset implementation for Ulysses pools
contract UlyssesToken is ERC4626MultiToken, Ownable, IUlyssesToken {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    uint256 public immutable id;

    constructor(
        uint256 _id,
        address[] memory _assets,
        uint256[] memory _weights,
        string memory _name,
        string memory _symbol,
        address _owner
    ) ERC4626MultiToken(_assets, _weights, _name, _symbol) {
        _initializeOwner(_owner);
        require(_id != 0);
        id = _id;
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC4626MultiToken
    function totalAssets() public view override returns (uint256 _totalAssets) {
        return totalSupply;
    }

    ///@inheritdoc IUlyssesToken
    function addAsset(address asset, uint256 _weight) external nonReentrant onlyOwner {
        if (assetId[asset] != 0) revert AssetAlreadyAdded();
        require(ERC20(asset).decimals() == 18);
        require(_weight > 0);

        assetId[asset] = assets.length + 1;
        assets.push(asset);
        weights.push(_weight);
        totalWeights += _weight;

        emit AssetAdded(asset, _weight);

        updateAssetBalances();
    }

    ///@inheritdoc IUlyssesToken
    function removeAsset(address asset) external nonReentrant onlyOwner {
        // No need to check if index is 0, it will underflow and revert if it is 0
        uint256 assetIndex = assetId[asset] - 1;

        uint256 newAssetsLength = assets.length - 1;

        if (newAssetsLength == 0) revert CannotRemoveLastAsset();

        totalWeights -= weights[assetIndex];

        address lastAsset = assets[newAssetsLength];

        assetId[lastAsset] = assetIndex;
        assets[assetIndex] = lastAsset;
        weights[assetIndex] = weights[newAssetsLength];

        assets.pop();
        weights.pop();
        assetId[asset] = 0;

        emit AssetRemoved(asset);

        updateAssetBalances();

        asset.safeTransfer(msg.sender, asset.balanceOf(address(this)));
    }

    ///@inheritdoc IUlyssesToken
    function setWeights(uint256[] memory _weights) external nonReentrant onlyOwner {
        if (_weights.length != assets.length) revert InvalidWeightsLength();

        weights = _weights;

        uint256 newTotalWeights;

        for (uint256 i = 0; i < assets.length; i++) {
            newTotalWeights += _weights[i];

            emit AssetRemoved(assets[i]);
            emit AssetAdded(assets[i], _weights[i]);
        }

        totalWeights = newTotalWeights;

        updateAssetBalances();
    }

    /**
     * @notice Update the balances of the underlying assets.
     */
    function updateAssetBalances() internal {
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 assetBalance = assets[i].balanceOf(address(this));
            uint256 newAssetBalance = totalSupply.mulDivUp(weights[i], totalWeights);

            if (assetBalance > newAssetBalance) {
                assets[i].safeTransfer(msg.sender, assetBalance - newAssetBalance);
            } else {
                assets[i].safeTransferFrom(msg.sender, address(this), newAssetBalance - assetBalance);
            }
        }
    }
}
