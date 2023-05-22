// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUlyssesERC4626 {
    /**
     * @notice Deposit assets into the Vault.
     * @param assets The amount of assets to deposit.
     * @param receiver The address to receive the shares.
     */
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /**
     * @notice Mint shares from the Vault.
     *  @param shares The amount of shares to mint.
     *  @param receiver The address to receive the shares.
     */
    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    /**
     * @notice Redeem assets from the Vault.
     * @param assets The amount of assets to Redeem.
     * @param receiver The address to receive the assets.
     * @param owner The address of the owner of the shares.
     */
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);

    /**
     * @notice Calculates the amount of shares that would be received for a given amount of assets.
     *  @param assets The amount of assets to deposit.
     */
    function convertToShares(uint256 assets) external view returns (uint256);

    /**
     * @notice Calculates the amount of assets that would be received for a given amount of shares.
     *  @param shares The amount of shares to redeem.
     */
    function convertToAssets(uint256 shares) external view returns (uint256);

    /**
     * @notice Previews the amount of shares that would be received for depositing given amount of assets.
     *  @param assets The amount of assets to deposit.
     */
    function previewDeposit(uint256 assets) external view returns (uint256);

    /**
     * @notice Previews the amount of assets that would be received for minting a given amount of shares
     *  @param shares The amount of shares to mint
     */
    function previewMint(uint256 shares) external view returns (uint256);

    /**
     * @notice Previews the amount of shares that would be received for redeeming a given amount of assets
     *  @param shares The amount of shares to redeem
     */
    function previewRedeem(uint256 shares) external view returns (uint256);

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
     * @notice Returns the maximum amount of shares that can be redeemed.
     *  @param owner The address of the owner of the shares.
     */
    function maxRedeem(address owner) external view returns (uint256);

    /* //////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Throw when adding an asset with decimals != 18
    error InvalidAssetDecimals();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(
        address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );
}
