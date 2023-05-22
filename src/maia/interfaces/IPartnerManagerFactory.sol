// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {ERC4626PartnerManager as PartnerManager, IBaseVault} from "../tokens/ERC4626PartnerManager.sol";

/**
 * @title Factory for managing PartnerManagers
 * @author Maia DAO (https://github.com/Maia-DAO)
 * @notice This contract is used to manage the list of partners and vaults.
 */
interface IPartnerManagerFactory {
    /*//////////////////////////////////////////////////////////////
                            PARTNER MANAGER STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The bHermes token.
    function bHermes() external view returns (ERC20);

    /// @notice Returns the partner manager at the given index.
    function partners(uint256) external view returns (PartnerManager);

    /// @notice Returns the vault at the given index.
    function vaults(uint256) external view returns (IBaseVault);

    /// @notice Returns the partner's list index for the given partner manager.
    function partnerIds(PartnerManager) external view returns (uint256);

    /// @notice Returns the vault's list index for the given vault.
    function vaultIds(IBaseVault) external view returns (uint256);

    /// @notice Used to get all partners managers created
    function getPartners() external view returns (PartnerManager[] memory);

    /// @notice Used to get all vaults created
    function getVaults() external view returns (IBaseVault[] memory);

    /*//////////////////////////////////////////////////////////////
                        NEW PARTNER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Used to add a new partner manager to the list of partners.
    function addPartner(PartnerManager newPartnerManager) external;

    /// @notice Used to add a new vault to the list of vaults.
    function addVault(IBaseVault newVault) external;

    /*//////////////////////////////////////////////////////////////
                        MIGRATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Used to remove a partner manager from the list of partners.
    function removePartner(PartnerManager partnerManager) external;

    /// @notice Used to remove a vault from the list of vaults.
    function removeVault(IBaseVault vault) external;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new partner manager is added.
    event AddedPartner(PartnerManager partnerManager, uint256 id);

    /// @notice Emitted when a new vault is added.
    event AddedVault(IBaseVault vault, uint256 id);

    /// @notice Emitted when a partner manager is removed.
    event RemovedPartner(PartnerManager indexed partnerManager);

    /// @notice Emitted when a vault is removed.
    event RemovedVault(IBaseVault indexed vault);

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error thrown when the partner manager is not found.
    error InvalidPartnerManager();

    /// @notice Error thrown when the vault is not found.
    error InvalidVault();
}
