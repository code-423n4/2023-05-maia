// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title Base Vault Contract.
 * @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice This contract allows for the management of bHermes utility tokens.
 *          Should be able to retrieve applied tokens at any time and transfer
 *          back to its owner(s).
 *
 *          NOTE: When added to a partner manager, the vault should use any
 *          utility tokens that are forfeited to it after calling `applyAll()`.
 *          Should be able to retrieve applied tokens at any time and transfer
 *          back to the vault when `clearAll()` is called.
 */
interface IBaseVault {
    function applyWeight() external;

    function applyBoost() external;

    function applyGovernance() external;

    function applyAll() external;

    function clearWeight(uint256 amount) external;

    function clearBoost(uint256 amount) external;

    function clearGovernance(uint256 amount) external;

    function clearAll() external;
}
