// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IERC4626 {
    /**
     * @notice Deposit assets into the Vault.
     * @param assets The amount of assets to deposit.
     * @param receiver The address to receive the shares.
     */
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /**
     * @notice Mint shares from the Vault.
     * @param shares The amount of shares to mint.
     * @param receiver The address to receive the shares.
     */
    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    /**
     * @notice Withdraw assets from the Vault.
     * @param assets The amount of assets to withdraw.
     * @param receiver The address to receive the assets.
     * @param owner The address to receive the shares.
     */
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    /**
     * @notice  Redeem shares from the Vault.
     * @param shares The amount of shares to redeem.
     * @param receiver The address to receive the assets.
     * @param owner The address to receive the shares.
     */
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);

    /**
     * @notice Calculates the amount of shares that would be received for a given amount of assets.
     * @param assets The amount of assets to deposit.
     */
    function convertToShares(uint256 assets) external view returns (uint256);

    /**
     * @notice  Calculates the amount of assets that would be received for a given amount of shares.
     * @param shares The amount of shares to redeem.
     */
    function convertToAssets(uint256 shares) external view returns (uint256);

    /**
     * @notice Preview the amount of shares that would be received for a given amount of assets.
     */
    function previewDeposit(uint256 assets) external view returns (uint256);

    /**
     * @notice Previews the amount of assets that would be received for minting a given amount of shares
     * @param shares The amount of shares to mint
     */
    function previewMint(uint256 shares) external view returns (uint256);

    /**
     * @notice Previews the amount of shares that would be received for a withdraw of a given amount of assets.
     * @param assets The amount of assets to withdraw.
     */
    function previewWithdraw(uint256 assets) external view returns (uint256);

    /**
     * @notice Previews the amount of assets that would be received for a redeem of a given amount of shares.
     */
    function previewRedeem(uint256 shares) external view returns (uint256);

    /**
     * @notice Returns the max amount of assets that can be deposited into the Vault.
     */
    function maxDeposit(address) external view returns (uint256);

    /**
     * @notice Returns the max amount of shares that can be minted from the Vault.
     */
    function maxMint(address) external view returns (uint256);

    /**
     * @notice Returns the max amount of assets that can be withdrawn from the Vault.
     */
    function maxWithdraw(address owner) external view returns (uint256);

    /**
     * @notice Returns the max amount of shares that can be redeemed from the Vault.
     */
    function maxRedeem(address owner) external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(
        address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );
}
