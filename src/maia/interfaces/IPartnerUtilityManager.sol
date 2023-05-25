// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {bHermesVotes as ERC20Votes} from "@hermes/tokens/bHermesVotes.sol";

/**
 * @title Partner Utility Tokens Manager Contract.
 * @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice When implemented, this contract allows for the partner
 *          management of bHermes utility tokens.
 */
interface IPartnerUtilityManager {
    /*//////////////////////////////////////////////////////////////
                         UTILITY MANAGER STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice address applying unused utility tokens.
    function partnerVault() external view returns (address);

    /// @notice Partner Underlying Token which grants governance rights.
    function partnerGovernance() external view returns (ERC20Votes);

    /// @notice Mapping of different user's Partner Governance withdrawn from vault.
    function userClaimedPartnerGovernance(address) external view returns (uint256);

    /*///////////////////////////////////////////////////////////////
                        UTILITY TOKENS LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Forfeits multiple amounts of multiple utility tokens.
    function forfeitMultipleAmounts(uint256 weight, uint256 boost, uint256 _governance, uint256 partnerGovernance)
        external;

    /// @notice Forfeits amounts of partner governance utility token.
    /// @param amount The amount to send to partner manager
    function forfeitPartnerGovernance(uint256 amount) external;

    /// @notice Claims multiple amounts of multiple utility tokens.
    function claimMultipleAmounts(uint256 weight, uint256 boost, uint256 _governance, uint256 partnerGovernance)
        external;

    /// @notice Claims amounts of partner governance utility token.
    /// @param amount The amount to send to partner manager
    function claimPartnerGovernance(uint256 amount) external;
}
