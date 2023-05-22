// SPDX-License-Identifier: MIT
// Logic inspired by Popsicle Finance Contracts (PopsicleV3Optimizer/contracts/popsicle-v3-optimizer/PopsicleV3Optimizer.sol)
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import {IUniswapV3Staker} from "@v3-staker/interfaces/IUniswapV3Staker.sol";
import {ITalosOptimizer} from "./ITalosOptimizer.sol";

/**
 * @title Tokenized Vault implementation for Uniswap V3 Non Fungible Positions.
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice This contract is responsible for managing a Uniswap V3 Non Fungible Position.
 *         TalosBaseStrategy allows the implementation two managing functions:
 *          - rerange
 *          - rebalance
 *         Both these actions are performed according to Talos Optimzer's values.
 *
 *         The underlying Uniswap V3 Pool NFT can be staked in any other contract by
 *         using internal hooks.
 */
interface ITalosBaseStrategy is IERC721Receiver {
    /// @notice Any data passed through by the caller via the IUniswapV3PoolActions#swap call
    struct SwapCallbackData {
        bool zeroForOne;
    }

    /*//////////////////////////////////////////////////////////////
                        TALOS BASE STRATEGY STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The token ID of the NFT held by the Position
    /// @return tokenId of the position
    function tokenId() external view returns (uint256);

    /// @notice The total liquidity held by the position
    /// @return liquidity of the position
    function liquidity() external view returns (uint128);

    /// @notice Accrued protocol fees in terms of token0
    function protocolFees0() external view returns (uint256);

    /// @notice  Accrued protocol fees in terms of token1
    function protocolFees1() external view returns (uint256);

    /// @notice The lower tick of the range
    function tickLower() external view returns (int24);

    /// @notice The upper tick of the range
    function tickUpper() external view returns (int24);

    /// @notice Checks if Optimizer is initialized
    function initialized() external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The first of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token0() external view returns (ERC20);

    /// @notice The second of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token1() external view returns (ERC20);

    /// @notice The pool tick spacing
    /// @dev Ticks can only be used at multiples of this value, minimum of 1 and always positive
    /// e.g.: a tickSpacing of 3 means ticks can be initialized every 3rd tick, i.e., ..., -6, -3, 0, 3, 6, ...
    /// This value is an int24 to avoid casting even though it is always positive.
    /// @return The tick spacing
    function tickSpacing() external view returns (int24);

    /// @notice The fee from Uniswap pool
    /// @return poolFee
    function poolFee() external view returns (uint24);

    /// @notice A Uniswap pool facilitates swapping and automated market-making between any two assets that strictly conform
    /// to the ERC20 specification
    /// @return The address of the Uniswap V3 Pool
    function pool() external view returns (IUniswapV3Pool);

    /// @notice The TalosOptimizer of this position
    /// @return optimizer of this position
    function optimizer() external view returns (ITalosOptimizer);

    /// @notice This position's strategy manager.
    /// @dev Can call rebalance and rerange.
    function strategyManager() external view returns (address);

    /// @notice The nonfungiblePositionManager to manage NFTs
    /// @return nonfungiblePositionManager
    function nonfungiblePositionManager() external view returns (INonfungiblePositionManager);

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the Optimizer with the given parameters.
    /// @dev Makes first deposit and mints tokenId.
    function init(uint256 amount0Desired, uint256 amount1Desired, address receiver)
        external
        returns (uint256 shares, uint256 amount0, uint256 amount1);

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits tokens in proportion to the Optimizer's current ticks.
     * @param amount0Desired Max amount of token0 to deposit
     * @param amount1Desired Max amount of token1 to deposit
     * @param receiver address that tlp should be transfered
     * @return shares minted
     * @return amount0 Amount of token0 deposited
     * @return amount1 Amount of token1 deposited
     */
    function deposit(uint256 amount0Desired, uint256 amount1Desired, address receiver)
        external
        returns (uint256 shares, uint256 amount0, uint256 amount1);

    /**
     * @notice Withdraws tokens in proportion to the Optimizer's holdings.
     * @dev Removes proportional amount of liquidity from Uniswap.
     * @param shares burned
     * @param amount0Min Min amount of token0 to withdraw
     * @param amount1Min Min amount of token1 to withdraw
     * @param receiver address that tokens should be transfered
     * @param owner of the shares to be burned
     * @return amount0 Amount of token0 sent to recipient
     * @return amount1 Amount of token1 sent to recipient
     */
    function redeem(uint256 shares, uint256 amount0Min, uint256 amount1Min, address receiver, address owner)
        external
        returns (uint256 amount0, uint256 amount1);

    /*//////////////////////////////////////////////////////////////
                        RERANGE/REBALANCE LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates Optimizer's positions. Can only be called by the strategy manager.
     * @dev Finds base position and limit position for imbalanced token
     * mints all amounts to this position (including earned fees)
     */
    function rerange() external;

    /**
     * @notice Updates Optimizer's positions. Can only be called by the strategy manager.
     * @dev Swaps imbalanced token. Finds base position and limit position for imbalanced token if
     * we don't have balance during swap because of price impact.
     * mints all amounts to this position (including earned fees)
     */
    function rebalance() external;

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL HOOKS
    //////////////////////////////////////////////////////////////*/

    /// @notice Called to `msg.sender` after minting swaping from IUniswapV3Pool#swap.
    /// @dev In the implementation you must pay to the pool for swap.
    /// @param amount0 The amount of token0 due to the pool for the swap
    /// @param amount1 The amount of token1 due to the pool for the swap
    /// @param _data Any data passed through by the caller via the IUniswapV3PoolActions#swap call
    function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes calldata _data) external;

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Used to withdraw accumulated protocol fees.
    function collectProtocolFees(uint256 amount0, uint256 amount1) external;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when user collects his fee share
    /// @param sender User address
    /// @param fees0 Exact amount of fees claimed by the users in terms of token 0
    /// @param fees1 Exact amount of fees claimed by the users in terms of token 1
    event RewardPaid(address indexed sender, uint256 fees0, uint256 fees1);

    /// @notice Emitted when TalosV3 Optimizer is initialized
    /// @param tokenId Token Id of the position
    /// @param caller Address of the caller
    /// @param owner Address of the owner
    /// @param amount0 Amount of token 0 deposited to the position
    /// @param amount1 Amount of token 1 deposited to the position
    /// @param shares Amount of shares minted
    event Initialize(
        uint256 indexed tokenId,
        address indexed caller,
        address indexed owner,
        uint256 amount0,
        uint256 amount1,
        uint256 shares
    );

    /// @notice Emitted when TalosV3 Optimizer is deposited
    /// @param caller Address of the caller
    /// @param owner Address of the owner
    /// @param amount0 Amount of token 0 deposited to the position
    /// @param amount1 Amount of token 1 deposited to the position
    /// @param shares Amount of shares minted
    event Deposit(address indexed caller, address indexed owner, uint256 amount0, uint256 amount1, uint256 shares);

    /// @notice Emitted when TalosV3 Optimizer is redeemed
    /// @param caller Address of the caller
    /// @param receiver Address of the receiver
    /// @param owner Address of the owner
    /// @param amount0 Amount of token 0 deposited to the position
    /// @param amount1 Amount of token 1 deposited to the position
    /// @param shares Amount of shares minted
    event Redeem(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 amount0,
        uint256 amount1,
        uint256 shares
    );

    /// @notice Emitted when TalosV3 Optimizer changes the position in the pool
    /// @param tokenId Token Id of the position
    /// @param tickLower Lower price tick of the positon
    /// @param tickUpper Upper price tick of the position
    /// @param amount0 Amount of token 0 deposited to the position
    /// @param amount1 Amount of token 1 deposited to the position
    event Rerange(uint256 indexed tokenId, int24 tickLower, int24 tickUpper, uint256 amount0, uint256 amount1);

    /// @notice Shows current Optimizer's balances
    /// @param totalAmount0 Current token0 Optimizer's balance
    /// @param totalAmount1 Current token1 Optimizer's balance
    event Snapshot(uint256 totalAmount0, uint256 totalAmount1);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error emitted when caller is not the strategy manager
    error NotStrategyManager();

    /// @notice Error emitted when trying to initialize an already initialized pool
    error AlreadyInitialized();

    /// @notice Error emitted when trying to add more liquidity than maxTotalSupply
    error ExceedingMaxTotalSupply();

    /// @notice Error emitted when caller is not the Uniswap V3 Pool
    error CallerIsNotPool();

    /// @notice Error emitted when both amounts are zero
    error AmountsAreZero();

    /// @notice Error emitted when widthdrawing zero shares
    error RedeemingZeroShares();

    /// @notice Error emitted when receiver is zero address
    error ReceiverIsZeroAddress();

    // Token 0 amount is bigger than accrued protocol fees
    error Token0AmountIsBiggerThanProtocolFees();

    // Token 1 amount is bigger than accrued protocol fees
    error Token1AmountIsBiggerThanProtocolFees();
}
