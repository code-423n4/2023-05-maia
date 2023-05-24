// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import {bHermesBoost} from "@hermes/tokens/bHermesBoost.sol";
import {UniswapV3Staker} from "@v3-staker/UniswapV3Staker.sol";

/**
 * @title Boost Aggregator for Uniswap V3 NFTs
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice This contract is used to aggregate Uniswap V3 NFTs from multiple addresses and
 *          stake them in the Uniswap V3 Staker contract, sharing the same boost.
 *          This contract allows for boost management and rewards distribution. so users
 *          can stake their NFTs and receive boosted hermes rewards.
 */
interface IBoostAggregator is IERC721Receiver {
    /*//////////////////////////////////////////////////////////////
                        BOOST AGGREGATOR STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice nonfungiblePositionManager contract
    function nonfungiblePositionManager() external view returns (INonfungiblePositionManager);

    /// @notice uniswapV3Staker contract
    function uniswapV3Staker() external view returns (UniswapV3Staker);

    ///@notice hermesGaugeBoost token
    function hermesGaugeBoost() external view returns (bHermesBoost);

    /// @notice hermes token
    function hermes() external view returns (ERC20);

    /// @notice mapping of user to rewardsDepot
    function userToRewardsDepot(address) external view returns (address);

    /// @notice mapping of tokenId to user
    function tokenIdToUser(uint256) external view returns (address);

    /// @notice mapping of tokenId to user
    function tokenIdRewards(uint256) external view returns (uint256);

    /// @notice mapping of whitelisted addresses
    function whitelistedAddresses(address) external view returns (bool);

    /// @notice protocol rewards
    function protocolRewards() external view returns (uint256);

    /// @notice protocol fee
    function protocolFee() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                        REWARD DEPOTS LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice set rewards depot for msg.sender
     * @param rewardsDepot address of rewards depot
     */
    function setOwnRewardsDepot(address rewardsDepot) external;

    /*//////////////////////////////////////////////////////////////
                            STAKE/UNSTAKE LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice unstake, withdraw, and claim rewards to user of tokenId
     * @param tokenId tokenId of position
     */
    function unstakeAndWithdraw(uint256 tokenId) external;

    /*//////////////////////////////////////////////////////////////
                            ADMIN LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice add whitelisted address to stake using this contract
     * @param user address of user
     */
    function addWhitelistedAddress(address user) external;

    /**
     * @notice remove whitelisted address from staking using this contract
     * @param user address of user
     */
    function removeWhitelistedAddress(address user) external;

    /**
     * @notice set protocol fee
     * @param _protocolFee protocol fee
     */
    function setProtocolFee(uint256 _protocolFee) external;

    /**
     * @notice withdraw protocol fees
     * @param to address to withdraw to
     */
    function withdrawProtocolFees(address to) external;

    /**
     * @notice withdraw all bHermesBoost
     * @param to address to withdraw to
     */
    function withdrawAllGaugeBoost(address to) external;

    /**
     * @notice withdraw bHermesBoost
     * @param to address to withdraw to
     * @param amount amount of boost to withdraw
     */
    function withdrawGaugeBoost(address to, uint256 amount) external;

    /**
     * @notice decrement all bHermesBoost
     * @param boost amount of boost to withdraw
     * @param offset offset of boost to withdraw
     * @param num number of boost to withdraw
     */
    function decrementGaugesBoostIndexed(uint256 boost, uint256 offset, uint256 num) external;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev throws when trying to set fees larger than 100%
    error FeeTooHigh();

    /// @dev throws when msg.sender is not the tokenId owner
    error NotTokenIdOwner();
}
