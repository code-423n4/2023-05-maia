// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {bHermesBoost} from "../tokens/bHermesBoost.sol";
import {bHermesGauges} from "../tokens/bHermesGauges.sol";
import {bHermesVotes as ERC20Votes} from "../tokens/bHermesVotes.sol";

/**
 * @title Utility Tokens Manager Contract.
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice When implemented, this contract allows for the management
 *          of bHermes utility tokens.
 */
interface IUtilityManager {
    /*//////////////////////////////////////////////////////////////
                         UTILITY MANAGER STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice bHermes Underlying Token responsible for allocating gauge weights.
    function gaugeWeight() external view returns (bHermesGauges);

    /// @notice bHermes Underlying Token for user boost accounting.
    function gaugeBoost() external view returns (bHermesBoost);

    /// @notice bHermes Underlying Token which grants governance rights.
    function governance() external view returns (ERC20Votes);

    /// @notice Mapping of different user's bHermes Gauge Weight withdrawn from vault.
    function userClaimedWeight(address) external view returns (uint256);

    /// @notice Mapping of different user's bHermes Boost withdrawn from vault.
    function userClaimedBoost(address) external view returns (uint256);

    /// @notice Mapping of different user's bHermes Governance withdrawn from vault.
    function userClaimedGovernance(address) external view returns (uint256);

    /*///////////////////////////////////////////////////////////////
                        UTILITY TOKENS LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Forfeits the same amounts of multiple utility tokens.
    function forfeitMultiple(uint256 amount) external;

    /// @notice Forfeits multiple amounts of multiple utility tokens.
    function forfeitMultipleAmounts(uint256 weight, uint256 boost, uint256 _governance) external;

    /// @notice Forfeits amounts of weight utility token.
    /// @param amount The amount to send to partner manager
    function forfeitWeight(uint256 amount) external;

    /// @notice Forfeits amounts of boost utility token.
    /// @param amount The amount to send to partner manager
    function forfeitBoost(uint256 amount) external;

    /// @notice Forfeits amounts of governance utility token.
    /// @param amount The amount to send to partner manager
    function forfeitGovernance(uint256 amount) external;

    /// @notice Claims the same amounts of multiple utility tokens.
    function claimMultiple(uint256 amount) external;

    /// @notice Claims multiple amounts of multiple utility tokens.
    function claimMultipleAmounts(uint256 weight, uint256 boost, uint256 _governance) external;

    /// @notice Claims amounts of weight utility token.
    /// @param amount The amount to send to partner manager
    function claimWeight(uint256 amount) external;

    /// @notice Claims amounts of boost utility token.
    /// @param amount The amount to send to partner manager
    function claimBoost(uint256 amount) external;

    /// @notice Claims amounts of governance utility token.
    /// @param amount The amount to send to partner manager
    function claimGovernance(uint256 amount) external;

    /*///////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a user forfeits weight.
    event ForfeitWeight(address indexed user, uint256 amount);

    /// @notice Emitted when a user forfeits boost.
    event ForfeitBoost(address indexed user, uint256 amount);

    /// @notice Emitted when a user forfeits governance.
    event ForfeitGovernance(address indexed user, uint256 amount);

    /// @notice Emitted when a user claims weight.
    event ClaimWeight(address indexed user, uint256 amount);

    /// @notice Emitted when a user claims boost.
    event ClaimBoost(address indexed user, uint256 amount);

    /// @notice Emitted when a user claims governance.
    event ClaimGovernance(address indexed user, uint256 amount);

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Insufficient vault shares for action.
    error InsufficientShares();
}
