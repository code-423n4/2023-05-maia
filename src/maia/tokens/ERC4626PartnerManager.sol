// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {ERC4626} from "@ERC4626/ERC4626.sol";

import {bHermes} from "@hermes/bHermes.sol";
import {bHermesVotes as ERC20MultiVotes} from "@hermes/tokens/bHermesVotes.sol";

import {PartnerManagerFactory} from "../factories/PartnerManagerFactory.sol";
import {IBaseVault} from "../interfaces/IBaseVault.sol";
import {PartnerUtilityManager} from "../PartnerUtilityManager.sol";

import {IERC4626PartnerManager} from "../interfaces/IERC4626PartnerManager.sol";

/// @title Yield bearing, boosting, voting, and gauge enabled Partner Token
abstract contract ERC4626PartnerManager is PartnerUtilityManager, Ownable, ERC4626, IERC4626PartnerManager {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                         PARTNER MANAGER STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC4626PartnerManager
    PartnerManagerFactory public immutable override factory;

    /// @inheritdoc IERC4626PartnerManager
    bHermes public immutable override bHermesToken;

    /// @inheritdoc IERC4626PartnerManager
    uint256 public override bHermesRate;

    /**
     * @notice Initializes the ERC4626PartnerManager token.
     * @param _factory The partner manager factory.
     * @param _bHermesRate The rate at which bHermes underlying's can be claimed.
     * @param _partnerAsset The asset that will be used to deposit to get partner tokens.
     * @param _name The name of the token.
     * @param _symbol The symbol of the token.
     * @param _bhermes The address of the bHermes token.
     * @param _partnerVault The address of the partner vault.
     * @param _owner The owner of this contract.
     */
    constructor(
        PartnerManagerFactory _factory,
        uint256 _bHermesRate,
        ERC20 _partnerAsset,
        string memory _name,
        string memory _symbol,
        address _bhermes,
        address _partnerVault,
        address _owner
    )
        PartnerUtilityManager(
            address(bHermes(_bhermes).gaugeWeight()),
            address(bHermes(_bhermes).gaugeBoost()),
            address(bHermes(_bhermes).governance()),
            address(new ERC20MultiVotes(_owner)),
            partnerVault
        )
        ERC4626(
            _partnerAsset,
            string.concat(_name, " - Burned Hermes: Aggregated Gov + Yield + Boost"),
            string.concat(_symbol, "-bHermes")
        )
    {
        _initializeOwner(_owner);
        partnerVault = _partnerVault;
        factory = _factory;
        bHermesRate = _bHermesRate;
        bHermesToken = bHermes(_bhermes);
    }

    /*///////////////////////////////////////////////////////////////
                            UTILITY MANAGER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC4626PartnerManager
    function updateUnderlyingBalance() public virtual {
        bHermesToken.claimOutstanding();
    }

    /// @inheritdoc IERC4626PartnerManager
    function claimOutstanding() public virtual {
        uint256 balance = balanceOf[msg.sender] * bHermesRate;
        /// @dev Never overflows since balandeOf >= userClaimed.
        claimWeight(balance - userClaimedWeight[msg.sender]);
        claimBoost(balance - userClaimedBoost[msg.sender]);
        claimGovernance(balance - userClaimedGovernance[msg.sender]);
        claimPartnerGovernance(balance - userClaimedPartnerGovernance[msg.sender]);
    }

    /*//////////////////////////////////////////////////////////////
                        ERC4626 ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Compute the amount of tokens available in contract.
    /// @dev 1:1 with underlying asset.
    function totalAssets() public view override returns (uint256) {
        return totalSupply;
    }

    /**
     * @notice Computes and returns the amount of shares from a given amount of assets.
     * @param assets amount of assets to convert to shares
     */
    function convertToShares(uint256 assets) public view virtual override returns (uint256) {
        return assets;
    }

    /**
     * @notice Computes and returns the amount of assets from a given amount of shares.
     * @param shares amount of shares to convert to assets
     */
    function convertToAssets(uint256 shares) public view virtual override returns (uint256) {
        return shares;
    }

    /**
     * @notice Simulates the amount of shares that the assets deposited are worth.
     * @param assets amount of assets to simulate the deposit.
     */
    function previewDeposit(uint256 assets) public view virtual override returns (uint256) {
        return assets;
    }

    /**
     * @notice Calculates the amount of shares that the assets deposited are worth.
     */
    function previewMint(uint256 shares) public view virtual override returns (uint256) {
        return shares;
    }

    /**
     * @notice Previews the amount of assets to be withdrawn from a given amount of shares.
     */
    function previewWithdraw(uint256 assets) public view virtual override returns (uint256) {
        return assets;
    }

    /**
     * @notice Previews the amount of assets to be redeemed from a given amount of shares.
     * @param shares amount of shares to convert to assets.
     */
    function previewRedeem(uint256 shares) public view virtual override returns (uint256) {
        return shares;
    }

    /*//////////////////////////////////////////////////////////////
                    ER4626 DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the maximum amount of assets that can be deposited by a user.
    /// @dev Returns the remaining balance of the bHermes divided by the bHermesRate.
    function maxDeposit(address) public view virtual override returns (uint256) {
        return (address(bHermesToken).balanceOf(address(this))) / bHermesRate - totalSupply;
    }

    /// @notice Returns the maximum amount of assets that can be deposited by a user.
    /// @dev Returns the remaining balance of the bHermes divided by the bHermesRate.
    function maxMint(address) public view virtual override returns (uint256) {
        return (address(bHermesToken).balanceOf(address(this))) / bHermesRate - totalSupply;
    }

    /// @notice Returns the maximum amount of assets that can be withdrawn by a user.
    /// @dev Assumes that the user has already forfeited all utility tokens.
    function maxWithdraw(address user) public view virtual override returns (uint256) {
        return balanceOf[user];
    }

    /// @notice Returns the maximum amount of assets that can be redeemed by a user.
    /// @dev Assumes that the user has already forfeited all utility tokens.
    function maxRedeem(address user) public view virtual override returns (uint256) {
        return balanceOf[user];
    }

    /*///////////////////////////////////////////////////////////////
                             MIGRATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC4626PartnerManager
    function migratePartnerVault(address newPartnerVault) external onlyOwner {
        if (factory.vaultIds(IBaseVault(newPartnerVault)) == 0) revert UnrecognizedVault();

        address oldPartnerVault = partnerVault;
        if (oldPartnerVault != address(0)) IBaseVault(oldPartnerVault).clearAll();
        bHermesToken.claimOutstanding();

        address(gaugeWeight).safeApprove(oldPartnerVault, 0);
        address(gaugeBoost).safeApprove(oldPartnerVault, 0);
        address(governance).safeApprove(oldPartnerVault, 0);
        address(partnerGovernance).safeApprove(oldPartnerVault, 0);

        address(gaugeWeight).safeApprove(newPartnerVault, type(uint256).max);
        address(gaugeBoost).safeApprove(newPartnerVault, type(uint256).max);
        address(governance).safeApprove(newPartnerVault, type(uint256).max);
        address(partnerGovernance).safeApprove(newPartnerVault, type(uint256).max);

        partnerVault = newPartnerVault;
        if (newPartnerVault != address(0)) IBaseVault(newPartnerVault).applyAll();

        emit MigratePartnerVault(address(this), newPartnerVault);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC4626PartnerManager
    function increaseConversionRate(uint256 newRate) external onlyOwner {
        if (newRate < bHermesRate) revert InvalidRate();

        if (newRate > (address(bHermesToken).balanceOf(address(this)) / totalSupply)) {
            revert InsufficientBacking();
        }

        bHermesRate = newRate;

        partnerGovernance.mint(
            address(this), totalSupply * newRate - address(partnerGovernance).balanceOf(address(this))
        );
        bHermesToken.claimOutstanding();
    }

    /*///////////////////////////////////////////////////////////////
                             ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints new partner bhermes tokens to a specific address.
     * @param to address to mints tokens to.
     * @param amount amount of tokens to mint.
     */
    function _mint(address to, uint256 amount) internal virtual override {
        if (amount > maxMint(to)) revert ExceedsMaxDeposit();
        bHermesToken.claimOutstanding();

        ERC20MultiVotes(partnerGovernance).mint(address(this), amount * bHermesRate);
        super._mint(to, amount);
    }

    /**
     * @notice Burns (or unstakes) the vMaia token in exchange for the underlying
     *         Partner tokens, performing changes around bHermes tokens.
     * @param from account to burn the partner manager from
     * @param amount amounts of vMaia to burn
     */
    function _burn(address from, uint256 amount) internal virtual override checkTransfer(from, amount) {
        super._burn(from, amount);
    }

    /**
     * @notice Transfer partner manager to a specific address.
     * @param to address to transfer the tokens to.
     * @param amount amounts of tokens to transfer.
     */
    function transfer(address to, uint256 amount)
        public
        virtual
        override
        checkTransfer(msg.sender, amount)
        returns (bool)
    {
        return super.transfer(to, amount);
    }

    /**
     * @notice Transfer tokens from a given address.
     * @param from address to transfer the tokens from.
     * @param to address to transfer the tokens to.
     * @param amount amounts of tokens to transfer.
     */
    function transferFrom(address from, address to, uint256 amount)
        public
        virtual
        override
        checkTransfer(from, amount)
        returns (bool)
    {
        return super.transferFrom(from, to, amount);
    }

    /*///////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Checks available weight allows for call.
    modifier checkWeight(uint256 amount) virtual override {
        if (balanceOf[msg.sender] * bHermesRate < amount + userClaimedWeight[msg.sender]) {
            revert InsufficientShares();
        }
        _;
    }

    /// @dev Checks available boost allows for call.
    modifier checkBoost(uint256 amount) virtual override {
        if (balanceOf[msg.sender] * bHermesRate < amount + userClaimedBoost[msg.sender]) {
            revert InsufficientShares();
        }
        _;
    }

    /// @dev Checks available governance allows for call.
    modifier checkGovernance(uint256 amount) virtual override {
        if (balanceOf[msg.sender] * bHermesRate < amount + userClaimedGovernance[msg.sender]) {
            revert InsufficientShares();
        }
        _;
    }

    /// @dev Checks available partner governance allows for call.
    modifier checkPartnerGovernance(uint256 amount) virtual override {
        if (balanceOf[msg.sender] * bHermesRate < amount + userClaimedPartnerGovernance[msg.sender]) {
            revert InsufficientShares();
        }
        _;
    }

    modifier checkTransfer(address from, uint256 amount) virtual {
        uint256 userBalance = balanceOf[from] * bHermesRate;

        if (
            userBalance - userClaimedWeight[from] < amount || userBalance - userClaimedBoost[from] < amount
                || userBalance - userClaimedGovernance[from] < amount
                || userBalance - userClaimedPartnerGovernance[from] < amount
        ) revert InsufficientUnderlying();

        _;
    }
}
