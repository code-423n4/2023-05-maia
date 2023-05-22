// SPDX-License-Identifier: MIT
// Rewards logic inspired by Uniswap V3 Contracts (Uniswap/v3-staker/contracts/UniswapV3Staker.sol)
pragma solidity ^0.8.0;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import {UniswapV3Gauge} from "@gauges/UniswapV3Gauge.sol";

import {bHermesBoost} from "@hermes/tokens/bHermesBoost.sol";

/**
 * @title Uniswap V3 Staker Interface with bHermes Boost.
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice Allows staking non-fungible liquidity tokens in exchange for reward tokens.
 *
 *
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣀⣤⣤⣤⣄⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣾⣿⣿⣿⣿⣟⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⣾⣿⣿⣿⠋⣸⣿⣿⣿⣿⣿⠹⣿⣿⣿⣿⣿⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣾⣿⣿⣿⡿⠁⣰⣿⣿⣿⣿⣿⣿⡄⠙⣿⣿⣿⣿⣿⣷⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⣿⣿⣿⣿⠇⢠⣿⣿⣿⣿⢿⡟⣿⣃⣀⣹⣿⣿⣿⣿⣿⣷⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⣿⣿⣿⡿⣠⠿⣟⠉⠋⠉⠀⠁⠙⣿⣿⣽⢿⣿⣿⣿⣿⣿⣇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠞⠁⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⣿⣿⣿⣿⡿⢳⣿⢿⣧⠀⠀⠀⠀⠀⠃⠀⠛⢹⣿⣿⣿⣿⣆⢻⣆⠀⠀⠀⠀⠀⢀⡤⠖⠒⠋⢹⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣧⣿⣿⣿⡗⠀⠈⠋⠂⠀⠀⠀⠀⠀⠀⠀⠉⠑⡾⣿⣿⣿⣿⣿⠈⣿⠀⠀⢀⣤⡴⠋⠀⠀⠀⡇⢸⠀⠀⣀⠔
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢈⣟⣿⣿⣿⣧⣄⠀⠀⠁⠀⣠⠴⠒⠒⠲⡄⠀⢰⡇⣿⣿⣿⣿⣿⠀⣿⠤⠴⡋⠀⠀⠀⠀⠀⠀⢃⠀⡷⠊⠁⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡞⠹⣿⣿⣿⣿⣿⣆⠀⠀⠀⠙⠳⠶⠶⠋⠀⠀⣼⣾⣿⣿⣿⣿⡟⣸⠏⠀⠀⡇⠀⠀⠀⠀⠀⠀⢸⣀⡇⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠞⠀⠀⢻⣿⣿⣿⣿⣿⣷⣤⣄⣀⡀⠀⠀⣀⣠⠾⣿⣿⣿⣿⣿⣿⣿⢟⠀⠀⢰⠁⠀⠀⠀⠀⠀⠀⢸⡿⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⠤⠞⠁⠀⠀⠀⠰⡿⣿⣿⣿⣿⣿⣿⣿⣩⣿⠗⠛⠒⠀⣸⣿⣿⣿⣿⣿⡿⠑⢸⠀⠀⡸⠀⠀⠀⡀⠀⠀⢀⠟⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠑⢻⣿⣿⣿⣿⣿⡏⢹⠱⢄⣀⠤⠚⣿⣿⣿⣿⣿⠯⡇⠀⠀⡆⠀⡇⠀⠀⢸⠃⠀⢠⠟⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣾⣿⣿⣿⣿⣿⢄⠸⡇⠀⠀⠀⢺⣿⣿⣏⣿⡏⠚⣧⡀⠀⢻⡀⠇⠀⠀⣼⠀⢠⠏⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡤⢒⠟⡅⠸⣿⣿⢺⢹⡈⢦⣣⠀⠀⠀⢸⡀⢿⡿⠌⡟⠀⠀⠀⠀⠀⢣⡀⠀⠀⡏⢠⠟⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⠔⠁⠐⠃⠀⠻⡄⠀⠘⠜⠛⢧⡈⢻⡄⢀⣶⣿⡿⠀⠀⢺⠃⠀⠀⠀⠀⠀⠘⡇⠀⢸⣠⡏⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣰⠏⣡⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠙⢲⣽⣾⣿⣋⣤⣄⣀⣼⡇⠀⠀⠀⠀⠀⠀⢸⡀⣼⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⡠⠴⠋⠁⠀⡄⡇⠀⠀⠳⣄⠀⠀⠀⠘⡆⠀⠀⠀⠀⠀⣼⣿⣿⣋⢁⣀⠉⠉⠘⡇⠀⠀⠀⠀⠀⠀⠀⢳⡍⣿⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣇⢷⠀⠀⠀⠈⠳⣄⠀⠀⢿⠀⠀⠀⠀⠀⡛⢛⡇⠘⣟⠉⡗⠀⣤⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⡟⣇⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⡠⠤⠘⠦⣳⣤⡤⣄⣀⡬⠷⣄⡘⡄⠀⢠⠀⢸⡇⢸⣇⣴⠟⠛⣽⣲⣿⡯⡄⠀⠀⠀⠀⠀⠀⠀⠀⡇⢸⡀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠁⠀⠀⠀⠀⠈⠁⠀⠀⠀⠀⠀⠀⠙⣇⠀⡎⠀⢸⣷⣾⡟⢁⣦⣤⣭⣿⣸⡁⢻⠀⠀⠀⠀⠀⠀⠀⠀⡇⠈⣧⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⣤⠇⠀⢸⡿⣟⠀⠘⢻⠁⠀⠀⠋⠉⠙⣇⠀⠀⠀⠀⠀⠀⠀⡇⠀⠙⢧⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⠀⠀⣾⡇⠈⠃⠀⠈⣧⠀⠀⠀⠀⠀⢻⡄⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⢷⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⠇⠀⠀⣿⢱⠀⠀⠀⠀⠸⡄⠀⠀⠀⠀⠸⣷⠀⠀⠀⠀⠀⠀⠁⠀⠀⠀⠘⡆⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡼⠀⠀⢠⡏⠸⡀⠀⠀⠀⠀⢻⡄⠀⠀⠀⠀⠻⡆⠀⠀⠀⠀⠸⠀⠀⠀⠀⣼⠁⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⣤⡷⢄⠇⠀⠀⠀⠀⠀⠙⢆⠀⠀⠀⠀⢿⡀⠀⠀⠀⠀⠀⠀⠀⢰⠏⡆⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⢰⣿⣿⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⣷⡀⠀⠀⠀⠀⠀⣰⠃⣰⠃⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢣⠀⢸⣿⣟⠛⣦⢄⡀⠀⠀⠀⠀⠀⢀⣠⠤⠊⢉⡼⡇⠀⠀⠀⢀⡜⠁⣰⠃⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢦⡘⢿⣿⡄⠈⠙⠛⠿⠶⠶⠶⠯⠉⠀⠒⠈⠀⣀⣿⢀⣠⠴⠋⠠⠞⢹⠀⠀⠀
 */
interface IUniswapV3Staker is IERC721Receiver {
    /// @param pool The Uniswap V3 pool
    /// @param startTime The time when the epoch begins
    struct IncentiveKey {
        IUniswapV3Pool pool;
        uint96 startTime;
    }

    /// @notice Represents a staking incentive
    struct Incentive {
        uint256 totalRewardUnclaimed;
        uint160 totalSecondsClaimedX128;
        uint96 numberOfStakes;
    }

    /// @notice Represents the deposit of a liquidity NFT
    struct Deposit {
        address owner;
        int24 tickLower;
        int24 tickUpper;
        uint40 stakedTimestamp;
    }

    /// @notice Represents a staked liquidity NFT
    struct Stake {
        uint160 secondsPerLiquidityInsideInitialX128;
        uint96 liquidityNoOverflow;
        uint128 liquidityIfOverflow;
    }

    /*//////////////////////////////////////////////////////////////
                        UNISWAP V3 STAKER STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The Uniswap V3 Factory
    function factory() external view returns (IUniswapV3Factory);

    /// @notice The nonfungible position manager with which this staking contract is compatible
    function nonfungiblePositionManager() external view returns (INonfungiblePositionManager);

    /// @notice The max amount of seconds into the future the incentive startTime can be set
    function maxIncentiveStartLeadTime() external view returns (uint256);

    /// @notice Address to send undistributed rewards
    function minter() external view returns (address);

    /// @notice The reward token
    function hermes() external view returns (address);

    /// @notice bHermes boost token
    function hermesGaugeBoost() external view returns (bHermesBoost);

    /// @notice returns the pool address for a given gauge.
    function gaugePool(address) external view returns (IUniswapV3Pool);

    /// @notice gauges[IUniswapV3Pool] => UniswapV3Gauge
    function gauges(IUniswapV3Pool) external view returns (UniswapV3Gauge);

    /// @notice bribeDepots[IUniswapV3Pool] => bribeDepot;
    function bribeDepots(IUniswapV3Pool) external view returns (address);

    /// @notice poolsMinimumWidth[IUniswapV3Pool] => minimumWidth
    function poolsMinimumWidth(IUniswapV3Pool) external view returns (uint24);

    /// @notice Represents a staking incentive
    /// @param incentiveId The ID of the incentive computed from its parameters
    /// @return totalRewardUnclaimed The amount of reward token not yet claimed by users
    /// @return totalSecondsClaimedX128 Total liquidity-seconds claimed, represented as a UQ32.128
    /// @return numberOfStakes The count of deposits that are currently staked for the incentive
    function incentives(bytes32 incentiveId)
        external
        view
        returns (uint256 totalRewardUnclaimed, uint160 totalSecondsClaimedX128, uint96 numberOfStakes);

    /// @notice Returns information about a deposited NFT
    /// @return owner The owner of the deposited NFT
    /// @return tickLower The lower tick of the range
    /// @return tickUpper The upper tick of the range
    /// @return stakedTimestamp The time at which the liquidity was staked
    function deposits(uint256 tokenId)
        external
        view
        returns (address owner, int24 tickLower, int24 tickUpper, uint40 stakedTimestamp);

    /// @notice Returns tokenId of the attached position of user per pool
    /// @dev Returns 0 if no position is attached
    /// @param user The address of the user
    /// @param pool The Uniswap V3 pool
    /// @return tokenId The ID of the attached position
    function userAttachements(address user, IUniswapV3Pool pool) external view returns (uint256);

    /// @notice Returns information about a staked liquidity NFT
    /// @param tokenId The ID of the staked token
    /// @param incentiveId The ID of the incentive for which the token is staked
    /// @return secondsPerLiquidityInsideInitialX128 secondsPerLiquidity represented as a UQ32.128
    /// @return liquidity The amount of liquidity in the NFT as of the last time the rewards were computed
    function stakes(uint256 tokenId, bytes32 incentiveId)
        external
        view
        returns (uint160 secondsPerLiquidityInsideInitialX128, uint128 liquidity);

    /// @notice Returns amounts of reward tokens owed to a given address according to the last time all stakes were updated
    /// @param owner The owner for which the rewards owed are checked
    /// @return rewardsOwed The amount of the reward token claimable by the owner
    function rewards(address owner) external view returns (uint256 rewardsOwed);

    /// @notice For external accounting purposes only.
    /// @dev tokenIdRewards[owner] => tokenIdRewards
    /// @param tokenId The ID of the staked token
    /// @return rewards The total amount of rewards earned by the tokenId.
    function tokenIdRewards(uint256 tokenId) external view returns (uint256 rewards);

    /*//////////////////////////////////////////////////////////////
                        CREATE INCENTIVE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new incentive for the gauge's pool.
    /// @dev msg sender must be a registered gauge.
    /// @param reward The amount of reward tokens to be distributed
    function createIncentiveFromGauge(uint256 reward) external;

    /// @notice Creates a new liquidity mining incentive program
    /// @param key Details of the incentive to create
    /// @param reward The amount of reward tokens to be distributed
    function createIncentive(IncentiveKey memory key, uint256 reward) external;

    /*//////////////////////////////////////////////////////////////
                            END INCENTIVE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Ends an incentive after the incentive end time has passed and all stakes have been withdrawn
    /// @param key Details of the incentive to end
    /// @return refund The remaining reward tokens when the incentive is ended
    function endIncentive(IncentiveKey memory key) external returns (uint256 refund);

    /*//////////////////////////////////////////////////////////////
                            WITHDRAW TOKEN LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Withdraws a Uniswap V3 LP token `tokenId` from this contract to the recipient `to`
    /// @param tokenId The unique identifier of an Uniswap V3 LP token
    /// @param to The address where the LP token will be sent
    /// @param data An optional data array that will be passed along to the `to` address via the NFT safeTransferFrom
    function withdrawToken(uint256 tokenId, address to, bytes memory data) external;

    /*//////////////////////////////////////////////////////////////
                            REWARD LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfers `amountRequested` of accrued `rewardToken` rewards from the contract to the recipient `to`
    /// @param to The address where claimed rewards will be sent to
    /// @param amountRequested The amount of reward tokens to claim. Claims entire reward amount if set to 0.
    /// @return reward The amount of reward tokens claimed
    function claimReward(address to, uint256 amountRequested) external returns (uint256 reward);

    /// @notice Transfers `amountRequested` of accrued `rewardToken` rewards from the contract to the recipient `to`
    /// @param to The address where claimed rewards will be sent to
    /// @return reward The amount of reward tokens claimed
    function claimAllRewards(address to) external returns (uint256 reward);

    /// @notice Calculates the reward amount that will be received for the given stake
    /// @param key The key of the incentive
    /// @param tokenId The ID of the token
    /// @return reward The reward accrued to the NFT for the given incentive thus far
    /// @return secondsInsideX128 The seconds inside the tick range
    function getRewardInfo(IncentiveKey memory key, uint256 tokenId)
        external
        returns (uint256 reward, uint160 secondsInsideX128);

    /*//////////////////////////////////////////////////////////////
                            UNSTAKE TOKEN LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Unstakes a Uniswap V3 LP token from all it's staked incentives
    /// @param tokenId The ID of the token to unstake
    function unstakeToken(uint256 tokenId) external;

    /// @notice Unstakes a Uniswap V3 LP token
    /// @param key The key of the incentive for which to unstake the NFT
    /// @param tokenId The ID of the token to unstake
    function unstakeToken(IncentiveKey memory key, uint256 tokenId) external;

    /*//////////////////////////////////////////////////////////////
                            STAKE TOKEN LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Stakes a Uniswap V3 LP token
    /// @param tokenId The ID of the token to stake
    function stakeToken(uint256 tokenId) external;

    /*//////////////////////////////////////////////////////////////
                        GAUGE UPDATE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates the gauge for the given pool
    /// @dev Adds gauge to a pool and updates bribeDepot and poolMinimumWidth
    function updateGauges(IUniswapV3Pool uniswapV3Pool) external;

    /// @notice Updates the bribeDepot for the given pool
    function updateBribeDepot(IUniswapV3Pool uniswapV3Pool) external;

    /// @notice Updates the poolMinimumWidth for the given pool
    function updatePoolMinimumWidth(IUniswapV3Pool uniswapV3Pool) external;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Event emitted when a liquidity mining incentive has been created
    /// @param pool The Uniswap V3 pool
    /// @param startTime The time when the incentive program begins
    /// @param reward The amount of reward tokens to be distributed
    event IncentiveCreated(IUniswapV3Pool indexed pool, uint256 startTime, uint256 reward);

    /// @notice Event that can be emitted when a liquidity mining incentive has ended
    /// @param incentiveId The incentive which is ending
    /// @param refund The amount of reward tokens refunded
    event IncentiveEnded(bytes32 indexed incentiveId, uint256 refund);

    /// @notice Emitted when ownership of a deposit changes
    /// @param tokenId The ID of the deposit (and token) that is being transferred
    /// @param oldOwner The owner before the deposit was transferred
    /// @param newOwner The owner after the deposit was transferred
    event DepositTransferred(uint256 indexed tokenId, address indexed oldOwner, address indexed newOwner);

    /// @notice Event emitted when a Uniswap V3 LP token has been staked
    /// @param tokenId The unique identifier of an Uniswap V3 LP token
    /// @param liquidity The amount of liquidity staked
    /// @param incentiveId The incentive in which the token is staking
    event TokenStaked(uint256 indexed tokenId, bytes32 indexed incentiveId, uint128 liquidity);

    /// @notice Event emitted when a Uniswap V3 LP token has been unstaked
    /// @param tokenId The unique identifier of an Uniswap V3 LP token
    /// @param incentiveId The incentive in which the token is staking
    event TokenUnstaked(uint256 indexed tokenId, bytes32 indexed incentiveId);

    /// @notice Event emitted when a reward token has been claimed
    /// @param to The address where claimed rewards were sent to
    /// @param reward The amount of reward tokens claimed
    event RewardClaimed(address indexed to, uint256 reward);

    /// @notice Event emitted when updating the bribeDepot for a pool
    /// @param uniswapV3Pool The Uniswap V3 pool
    /// @param bribeDepot The bribeDepot for the pool
    event BribeDepotUpdated(IUniswapV3Pool indexed uniswapV3Pool, address bribeDepot);

    /// @notice Event emitted when updating the poolMinimumWidth for a pool
    /// @param uniswapV3Pool The Uniswap V3 pool
    /// @param poolMinimumWidth The poolMinimumWidth for the pool
    event PoolMinimumWidthUpdated(IUniswapV3Pool indexed uniswapV3Pool, uint24 indexed poolMinimumWidth);

    /// @notice Event emitted when updating the gauge address for a pool
    event GaugeUpdated(IUniswapV3Pool indexed uniswapV3Pool, address indexed uniswapV3Gauge);

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidGauge();

    error NotCalledByOwner();

    error IncentiveRewardMustBePositive();
    error IncentiveStartTimeMustBeNowOrInTheFuture();
    error IncentiveStartTimeNotAtEndOfAnEpoch();
    error IncentiveStartTimeTooFarIntoFuture();
    error IncentiveCallerMustBeRegisteredGauge();

    error IncentiveCannotBeCreatedForPoolWithNoGauge();

    error EndIncentiveBeforeEndTime();
    error EndIncentiveWhileStakesArePresent();
    error EndIncentiveNoRefundAvailable();

    error TokenNotUniswapV3NFT();

    error TokenNotStaked();
    error TokenNotDeposited();

    error InvalidRecipient();
    error TokenStakedError();

    error NonExistentIncentiveError();
    error RangeTooSmallError();
    error NoLiquidityError();
}
