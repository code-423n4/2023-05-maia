// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC4626MultiToken {
    /**
     * @notice Gets the address of the underlying asset at the given index.
     * @param index The index of the underlying asset.
     * @return asset address of the underlying asset.
     */
    function assets(uint256 index) external view returns (address asset);

    /**
     * @notice Gets the weight of the underlying asset at the given index.
     * @param index The index of the underlying asset.
     * @return weight of the underlying asset.
     */
    function weights(uint256 index) external view returns (uint256);

    /**
     * @notice Gets the ID of the underlying asset.
     * @dev assetId[asset] = index + 1
     * @param asset The address of the underlying asset.
     * @return assetId ID of the underlying asset.
     */
    function assetId(address asset) external view returns (uint256 assetId);

    /**
     * @notice Gets the sum of all weights.
     * @return totalWeights sum of all weights.
     */
    function totalWeights() external view returns (uint256 totalWeights);

    /**
     * @notice Gets all the underlying assets.
     * @return assets array of all the underlying assets.
     */
    function getAssets() external view returns (address[] memory assets);

    /**
     * @notice Calculates the total amount of assets of a given Ulysses token.
     * @return _totalAssets total number of underlying assets of a Ulysses token.
     */
    function totalAssets() external view returns (uint256 _totalAssets);

    /**
     * @notice Deposit assets into the Vault.
     * @param assetsAmounts The amount of assets to deposit.
     * @param receiver The address to receive the shares.
     */
    function deposit(uint256[] calldata assetsAmounts, address receiver) external returns (uint256 shares);

    /**
     * @notice Mint shares from the Vault.
     * @param shares The amount of shares to mint.
     * @param receiver The address to receive the shares.
     */
    function mint(uint256 shares, address receiver) external returns (uint256[] memory assetsAmounts);

    /**
     * @notice Withdraw assets from the Vault.
     * @param assetsAmounts The amount of assets to withdraw.
     * @param receiver The address to receive the assets.
     * @param owner The address of the owner of the shares.
     */
    function withdraw(uint256[] calldata assetsAmounts, address receiver, address owner)
        external
        returns (uint256 shares);

    /**
     * @notice Redeem shares from the Vault.
     * @param shares The amount of shares to redeem.
     * @param receiver The address to receive the assets.
     */
    function redeem(uint256 shares, address receiver, address owner)
        external
        returns (uint256[] memory assetsAmounts);

    /**
     * @notice Calculates the amount of shares that would be received for a given amount of assets.
     *  @param assetsAmounts The amount of assets to deposit.
     */
    function convertToShares(uint256[] calldata assetsAmounts) external view returns (uint256 shares);

    /**
     * @notice Calculates the amount of assets that would be received for a given amount of shares.
     *  @param shares The amount of shares to redeem.
     */
    function convertToAssets(uint256 shares) external view returns (uint256[] memory assetsAmounts);

    /**
     * @notice Previews the amount of shares that would be received for depositinga given amount of assets.
     *  @param assetsAmounts The amount of assets to deposit.
     */
    function previewDeposit(uint256[] calldata assetsAmounts) external view returns (uint256);

    /**
     * @notice Previews the amount of assets that would be received for minting a given amount of shares
     *  @param shares The amount of shares to mint
     */
    function previewMint(uint256 shares) external view returns (uint256[] memory assetsAmounts);

    /**
     * @notice Previews the amount of shares that would be received for a given amount of assets.
     *  @param assetsAmounts The amount of assets to withdraw.
     */
    function previewWithdraw(uint256[] calldata assetsAmounts) external view returns (uint256 shares);

    /**
     * @notice Previews the amount of assets that would be received for redeeming a given amount of shares
     *  @param shares The amount of shares to redeem
     */
    function previewRedeem(uint256 shares) external view returns (uint256[] memory);

    /**
     * @notice Returns the maximum amount of assets that can be deposited.
     *  @param owner The address of the owner of the assets.
     */
    function maxDeposit(address owner) external view returns (uint256);

    /**
     * @notice Returns the maximum amount of shares that can be minted.
     *  @param owner The address of the owner of the shares.
     */
    function maxMint(address owner) external view returns (uint256);

    /**
     * @notice Returns the maximum amount of assets that can be withdrawn.
     *  @param owner The address of the owner of the assets.
     */
    function maxWithdraw(address owner) external view returns (uint256[] memory);

    /**
     * @notice Returns the maximum amount of shares that can be redeemed.
     *  @param owner The address of the owner of the shares.
     */
    function maxRedeem(address owner) external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error thrown when redeeming returns 0 assets.
    error ZeroAssets();

    /// @notice Error thrown when depositing amounts array length is different than assets array length.
    error InvalidLength();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when assets are deposited into the Vault.
     * @param caller The caller of the deposit function.
     * @param owner The address of the owner of the shares.
     * @param assets The amount of assets deposited.
     * @param shares The amount of shares minted.
     */
    event Deposit(address indexed caller, address indexed owner, uint256[] assets, uint256 shares);

    /**
     * @notice Emitted when shares are withdrawn from the Vault.
     * @param caller The caller of the withdraw function.
     * @param receiver The address that received the assets.
     * @param owner The address of the owner of the shares.
     * @param assets The amount of assets withdrawn.
     * @param shares The amount of shares redeemed.
     */
    event Withdraw(
        address indexed caller, address indexed receiver, address indexed owner, uint256[] assets, uint256 shares
    );

    /**
     * @notice Emitted when a new asset is added to the Vault.
     * @param asset The address of the new asset.
     * @param weight The weight of the new asset.
     */
    event AssetAdded(address asset, uint256 weight);

    /**
     * @notice Emitted when an asset is removed from the Vault.
     * @param asset The address of the removed asset.
     */
    event AssetRemoved(address asset);
}
