// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import {SqrtPriceMath as SqrtPriceMathTest} from "@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {UniswapV3Factory, UniswapV3Pool} from "@uniswap/v3-core/contracts/UniswapV3Factory.sol";

import {IWETH9} from "@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {
    NonfungiblePositionManager, IUniswapV3Pool
} from "@uniswap/v3-periphery/contracts/NonfungiblePositionManager.sol";
import {SwapRouter} from "@uniswap/v3-periphery/contracts/SwapRouter.sol";

import {TalosBaseStrategy} from "@talos/base/TalosBaseStrategy.sol";
import {TalosOptimizer} from "@talos/TalosOptimizer.sol";
import {PoolVariables, PoolActions} from "@talos/libraries/PoolActions.sol";

abstract contract TalosTestor is DSTestPlus {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for uint160;
    using FixedPointMathLib for uint128;
    using SafeCastLib for uint256;
    using SafeCastLib for int256;
    using PoolVariables for IUniswapV3Pool;
    using PoolActions for IUniswapV3Pool;
    using SafeTransferLib for ERC20;
    using SafeTransferLib for MockERC20;

    //////////////////////////////////////////////////////////////////
    //                          STRUCTS
    //////////////////////////////////////////////////////////////////

    //Any data passed through by the caller via the IUniswapV3PoolActions#swap call
    struct SwapCallbackData {
        bool zeroForOne;
    }

    //////////////////////////////////////////////////////////////////
    //                          VARIABLES
    //////////////////////////////////////////////////////////////////

    uint24 constant MULTIPLIER = 1e6;
    uint24 constant GLOBAL_DIVISIONER = 1e6; // for basis point (0.0001%)

    TalosBaseStrategy talosBaseStrategy;
    TalosOptimizer strategyOptimizer;

    MockERC20 token0; // 0x0c7bbb021d72db4ffba37bdf4ef055eecdbc0a29
    MockERC20 token1; // 0x18669eb6c7dfc21dcdb787feb4b3f1ebb3172400

    MockERC20 rewardToken; // 0x0c7bbb021d72db4ffba37bdf4ef055eecdbc0a29

    UniswapV3Factory uniswapV3Factory;
    SwapRouter swapRouterContract;
    ISwapRouter swapRouter;

    NonfungiblePositionManager nonfungiblePositionManager;

    IUniswapV3Pool pool;
    UniswapV3Pool poolContract;

    IWETH9 WETH9 = IWETH9(address(0));

    address constant user0 = address(0xDEAD);
    address constant user1 = address(0xBEEF);
    address constant user2 = address(0xCAFE);

    //////////////////////////////////////////////////////////////////
    //                          SET UP
    //////////////////////////////////////////////////////////////////

    bool initTalosPosition = true;

    function init() public {
        token1 = new MockERC20("test token", "TKN", 18);
        token0 = new MockERC20("test token", "TKN", 18);
        rewardToken = new MockERC20("test token", "TKN", 18);
        token0.mint(address(this), 25e18);
        rewardToken.mint(address(this), 25e18);

        uniswapV3Factory = new UniswapV3Factory();

        swapRouterContract = new SwapRouter(address(uniswapV3Factory), address(WETH9));
        swapRouter = ISwapRouter(address(swapRouterContract));

        nonfungiblePositionManager = new NonfungiblePositionManager(
            address(uniswapV3Factory),
            address(WETH9),
            address(0)
        );

        /// @dev If this fails, please make cure POOL_INIT_CODE_HASH in PoolAddress.sol is updated and build the contract again
        address poolAddress = uniswapV3Factory.createPool(address(token0), address(token1), 3000);
        pool = IUniswapV3Pool(poolAddress);
        poolContract = UniswapV3Pool(poolAddress);
        poolContract.initialize(56022770974786139918731938227);
        poolContract.increaseObservationCardinalityNext(100);

        strategyOptimizer = new TalosOptimizer(100, 40, 16, 2000, type(uint256).max, address(this));

        initializeTalos();

        if (initTalosPosition) initTalosStrategy(talosBaseStrategy);
    }

    function initTalosStrategy(TalosBaseStrategy strategy) public {
        token0.mint(address(this), 1e18);
        token1.mint(address(this), 1e18);
        token0.approve(address(strategy), 1e18);
        token1.approve(address(strategy), 1e18);

        strategy.init(1e18, 1e18, address(this));
        hevm.warp(block.timestamp + 100);

        token0.approve(address(strategy), 0);
        token1.approve(address(strategy), 0);

        strategy.redeem(strategy.balanceOf(address(this)), 0, 0, address(this), address(this));
    }

    function initializeTalos() internal virtual;

    //////////////////////////////////////////////////////////////////
    //                          UTILS
    //////////////////////////////////////////////////////////////////

    function getTicks(TalosBaseStrategy strategy) public view returns (int24 tickLower, int24 tickUpper) {
        tickLower = strategy.tickLower();
        tickUpper = strategy.tickUpper();
    }

    function getProtocolFees(TalosBaseStrategy strategy)
        private
        view
        returns (uint256 protocolFees0, uint256 protocolFees1)
    {
        protocolFees0 = strategy.protocolFees0();
        protocolFees1 = strategy.protocolFees1();
    }

    function calcShare(uint256 amount0Desired, uint256 amount1Desired, TalosBaseStrategy strategy)
        private
        view
        returns (uint256 shares, uint128 liquidity)
    {
        (int24 tickLower, int24 tickUpper) = getTicks(strategy);

        uint128 liquidityLast = strategy.liquidity();

        // compute the liquidity amount
        liquidity = pool.liquidityForAmounts(amount0Desired, amount1Desired, tickLower, tickUpper);

        shares = strategy.totalSupply() == 0
            ? liquidity * MULTIPLIER
            : FullMath.mulDiv(liquidity, strategy.totalSupply(), liquidityLast);
    }

    function mintAmounts(uint128 liquidity, TalosBaseStrategy strategy)
        private
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (uint160 sqrtPriceX96, int24 tick,,,,,) = pool.slot0();
        (int24 tickLower, int24 tickUpper) = getTicks(strategy);

        uint160 tickLowerX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 tickUpperX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        if (tick < tickLower) {
            amount0 = SqrtPriceMathTest.getAmount0Delta(tickLowerX96, tickUpperX96, liquidity, true);
            amount1 = 0;
        } else {
            if (tick < tickUpper) {
                amount0 = SqrtPriceMathTest.getAmount0Delta(sqrtPriceX96, tickUpperX96, liquidity, true);
                amount1 = SqrtPriceMathTest.getAmount1Delta(tickLowerX96, sqrtPriceX96, liquidity, true);
            } else {
                amount0 = 0;
                amount1 = SqrtPriceMathTest.getAmount1Delta(tickLowerX96, tickUpperX96, liquidity, true);
            }
        }
    }

    function _deposit(uint256 amount0Desired, uint256 amount1Desired, address to, TalosBaseStrategy strategy)
        public
        returns (uint256 shares, uint256 amount0, uint256 amount1)
    {
        (uint256 predictedShares, uint128 liquidity) = calcShare(amount0Desired, amount1Desired, strategy);
        (uint256 predictedAmount0, uint256 predictedAmount1) = mintAmounts(liquidity, strategy);

        token0.mint(to, amount0Desired);
        token1.mint(to, amount1Desired);

        hevm.prank(to);
        token0.approve(address(strategy), amount0Desired);
        hevm.prank(to);
        token1.approve(address(strategy), amount1Desired);

        uint256 oldTotalSupply = strategy.totalSupply();
        uint256 oldShares = strategy.balanceOf(to);

        hevm.expectEmit(true, true, true, true);
        emit Deposit(to, to, predictedAmount0, predictedAmount1, predictedShares);

        hevm.prank(to);
        (shares, amount0, amount1) = strategy.deposit(amount0Desired, amount1Desired, to);

        assertEq(shares, strategy.totalSupply() - oldTotalSupply, "Incorrect shares");
        assertEq(oldShares + shares, strategy.balanceOf(to), "Incorrect balance");
        assertEq(shares, predictedShares, "Incorrect shares");

        hevm.warp(block.timestamp + 100);
    }

    function deposit(uint256 amount0Desired, uint256 amount1Desired, address to)
        public
        returns (uint256 shares, uint256 amount0, uint256 amount1)
    {
        return _deposit(amount0Desired, amount1Desired, to, talosBaseStrategy);
    }

    function burnAmounts(uint256 shares, TalosBaseStrategy strategy)
        private
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (int24 tickLower, int24 tickUpper) = getTicks(strategy);
        (uint256 protocolFees0, uint256 protocolFees1) = getProtocolFees(strategy);

        uint128 protocolLiquidity = pool.liquidityForAmounts(protocolFees0, protocolFees1, tickLower, tickUpper);

        uint128 liquidityInPool = strategy.liquidity();

        uint256 totalSupply = strategy.totalSupply();

        uint128 liquidity = uint128(FullMath.mulDiv(liquidityInPool - protocolLiquidity, shares, totalSupply));

        (amount0, amount1) = pool.amountsForLiquidity(liquidity, tickLower, tickUpper);
    }

    function _withdraw(uint256 shares, address to, TalosBaseStrategy strategy)
        private
        returns (uint256 amount0, uint256 amount1)
    {
        (uint256 predictedAmount0, uint256 predictedAmount1) = burnAmounts(shares, strategy);

        hevm.expectEmit(true, true, true, true);
        emit Redeem(to, to, to, predictedAmount0, predictedAmount1, shares);

        uint256 balance0 = token0.balanceOf(to);
        uint256 balance1 = token1.balanceOf(to);
        uint256 currentShare = strategy.balanceOf(to);
        uint256 oldTotalSupply = strategy.totalSupply();

        hevm.prank(to);
        (amount0, amount1) = strategy.redeem(shares, predictedAmount0, predictedAmount1, to, to);
        hevm.warp(block.timestamp + 100);

        assertEq(strategy.balanceOf(to), currentShare - shares, "Incorrect shares");
        assertEq(strategy.totalSupply(), oldTotalSupply - shares, "Incorrect shares");

        assertEq(amount0, predictedAmount0, "Incorrect amount0");
        assertEq(amount1, predictedAmount1, "Incorrect amount1");

        assertEq(token0.balanceOf(to), balance0 + amount0, "Incorrect balance0");
        assertEq(token1.balanceOf(to), balance1 + amount1, "Incorrect balance1");
    }

    function withdraw(uint256 shares, address to) public returns (uint256 amount0, uint256 amount1) {
        return _withdraw(shares, to, talosBaseStrategy);
    }

    function poolSwap(uint256 amountSpecified, bool zeroForOne) private {
        //Calc base ticks
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();

        // Calculate Price limit depending on price impact
        uint160 exactSqrtPriceImpact = (sqrtPriceX96 * (10000 / 2)) / GLOBAL_DIVISIONER;

        uint160 sqrtPriceLimitX96 =
            zeroForOne ? sqrtPriceX96 - exactSqrtPriceImpact : sqrtPriceX96 + exactSqrtPriceImpact;

        //Swap imbalanced token as long as we haven't used the entire amountSpecified and haven't reached the price limit
        pool.swap(
            address(this),
            zeroForOne,
            int256(amountSpecified),
            sqrtPriceLimitX96,
            abi.encode(SwapCallbackData({zeroForOne: zeroForOne}))
        );
    }

    function poolDisbalancer(uint8 percent) public {
        uint256 token0Balance = token0.balanceOf(address(pool));
        uint256 token1Balance = token1.balanceOf(address(pool));

        token0.mint(address(this), type(uint128).max);
        token1.mint(address(this), type(uint128).max);

        token0.approve(address(pool), type(uint128).max);
        token1.approve(address(pool), type(uint128).max);

        uint256 balance0 = token0Balance;
        uint256 balance1 = token1Balance;

        while (balance0 > (token0Balance * percent) / 100) {
            poolSwap(balance0 / 10, true);
            hevm.warp(block.timestamp + 100);

            poolSwap((balance1 * 15) / 100, false);
            hevm.warp(block.timestamp + 100);

            balance0 = token0.balanceOf(address(pool));
            balance1 = token1.balanceOf(address(pool));
        }
    }

    /// @notice Called to `msg.sender` after minting swaping from IUniswapV3Pool#swap.
    /// @dev In the implementation you must pay to the pool for swap.
    /// @param amount0 The amount of token0 due to the pool for the swap
    /// @param amount1 The amount of token1 due to the pool for the swap
    /// @param _data Any data passed through by the caller via the IUniswapV3PoolActions#swap call
    function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes calldata _data) external {
        require(msg.sender == address(pool), "FP");
        require(amount0 > 0 || amount1 > 0, "LEZ"); // swaps entirely within 0-liquidity regions are not supported
        SwapCallbackData memory data = abi.decode(_data, (SwapCallbackData));
        bool zeroForOne = data.zeroForOne;

        if (zeroForOne) token0.transfer(msg.sender, uint256(amount0));
        else token1.transfer(msg.sender, uint256(amount1));
    }

    //////////////////////////////////////////////////////////////////
    //                          EVENTS
    //////////////////////////////////////////////////////////////////

    event Deposit(address indexed caller, address indexed owner, uint256 amount0, uint256 amount1, uint256 shares);

    event Redeem(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 amount0,
        uint256 amount1,
        uint256 shares
    );

    /// @notice Emitted when TalosV3 Optimizer changes the position in the pool
    /// @param tokenId The new TokenId
    /// @param tickLower Lower price tick of the positon
    /// @param tickUpper Upper price tick of the position
    /// @param amount0 Amount of token 0 deposited to the position
    /// @param amount1 Amount of token 1 deposited to the position
    event Rerange(uint256 indexed tokenId, int24 tickLower, int24 tickUpper, uint256 amount0, uint256 amount1);

    /// @notice Emitted when user collects his fee share
    /// @param sender User address
    /// @param fees0 Exact amount of fees claimed by the users in terms of token 0
    /// @param fees1 Exact amount of fees claimed by the users in terms of token 1
    event RewardPaid(address indexed sender, uint256 fees0, uint256 fees1);
}
