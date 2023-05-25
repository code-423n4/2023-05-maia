// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {stdError} from "forge-std/StdError.sol";
import {Test} from "forge-std/Test.sol";

import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {UlyssesPool, IUlyssesPool} from "@ulysses-amm/UlyssesPool.sol";

import {
    UlyssesPoolHandlerBounded, UlyssesPoolHandler
} from "@test/test-utils/invariant/handlers/UlyssesPoolHandler.t.sol";

import {AddressSet, LibAddressSet} from "@test/test-utils/invariant/helpers/AddressSet.sol";

contract InvariantUlyssesPool is Test {
    using FixedPointMathLib for uint256;
    using LibAddressSet for AddressSet;
    using SafeCastLib for uint256;

    address public handler;

    uint256 constant MAX_DESTINATIONS = 15;
    uint256 constant MAX_TOTAL_WEIGHT = 256;

    /*//////////////////////////////////////////////////////////////
                            FEE PARAMETERS
    //////////////////////////////////////////////////////////////*/

    uint64 public protocolFee = 1e14;

    uint256 private constant DIVISIONER = 1 ether;

    function setUpHandler() public virtual {
        handler = address(new UlyssesPoolHandler());
    }

    function setUp() public {
        setUpHandler();

        excludeContract(handler);

        // bytes4[] memory selectors = new bytes4[](4);
        // selectors[0] = UlyssesPoolHandler.deposit.selector;
        // selectors[1] = UlyssesPoolHandler.mint.selector;
        // selectors[3] = UlyssesPoolHandler.redeem.selector;
        // selectors[4] = UlyssesPoolHandler.swapIn.selector;

        // bytes4[] memory selectors = new bytes4[](5);
        // selectors[0] = UlyssesPoolHandler.deposit.selector;
        // selectors[1] = UlyssesPoolHandler.mint.selector;
        // selectors[2] = UlyssesPoolHandler.redeem.selector;
        // selectors[3] = UlyssesPoolHandler.swapIn.selector;
        // selectors[4] = UlyssesPoolHandler.addNewBandwidth.selector;

        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = UlyssesPoolHandler.deposit.selector;
        selectors[1] = UlyssesPoolHandler.mint.selector;
        selectors[2] = UlyssesPoolHandler.redeem.selector;
        selectors[3] = UlyssesPoolHandler.swapIn.selector;
        selectors[4] = UlyssesPoolHandler.addNewBandwidth.selector;
        selectors[5] = UlyssesPoolHandler.claimProtocolFees.selector;

        targetSelector(FuzzSelector({addr: handler, selectors: selectors}));

        vm.startPrank(handler);

        createPools(5);

        // UlyssesPool[] memory newPools = createPools(5);
        // newPools[0].addNewBandwidth(2, 37);
        // newPools[0].addNewBandwidth(3, 37);
        // // newPools[0].addNewBandwidth(4, 37);
        // // newPools[0].addNewBandwidth(5, 37);
        // newPools[1].addNewBandwidth(1, 20);
        // newPools[1].addNewBandwidth(3, 80);
        // // newPools[1].addNewBandwidth(4, 37);
        // // newPools[1].addNewBandwidth(5, 37);
        // newPools[2].addNewBandwidth(1, 30);
        // newPools[2].addNewBandwidth(2, 70);
        // // newPools[2].addNewBandwidth(4, 37);
        // // newPools[2].addNewBandwidth(5, 37);
        // // newPools[3].addNewBandwidth(1, 37);
        // // newPools[3].addNewBandwidth(2, 37);
        // // newPools[3].addNewBandwidth(3, 37);
        // // newPools[3].addNewBandwidth(5, 37);
        // // newPools[4].addNewBandwidth(1, 37);
        // // newPools[4].addNewBandwidth(2, 37);
        // // newPools[4].addNewBandwidth(3, 37);
        // // newPools[4].addNewBandwidth(4, 37);

        vm.stopPrank();
    }

    function createPools(uint256 numPools) internal returns (UlyssesPool[] memory pools) {
        pools = new UlyssesPool[](numPools);

        for (uint256 i = 1; i <= numPools; i++) {
            address newUnderlying = address(new MockERC20("Mock Token", "TKN", 18));

            UlyssesPool newPool = new UlyssesPool(
                i,
                newUnderlying,
                "Mock Token Vault",
                "vwTKN",
                handler,
                handler
            );

            UlyssesPoolHandler(handler).addPool(newPool);
            pools[i - 1] = newPool;

            // Mock address(this) as UlyssesFactory
            vm.mockCall(handler, abi.encodeWithSignature("pools(uint256)", i), abi.encode(newPool));

            excludeContract(address(newUnderlying));
            excludeContract(address(newPool));
            excludeSender(address(newUnderlying));
            excludeSender(address(newPool));
        }
    }

    function invariant_CorrectBalance() public {
        UlyssesPoolHandler(handler).forEachPool(this.assertCorrectBalance);
    }

    function invariant_CorrectBalances() public {
        address[] memory pools = UlyssesPoolHandler(handler).pools();

        uint256 assets;
        uint256 balances;
        uint256 supplies;

        for (uint256 i = 0; i < pools.length; i++) {
            UlyssesPool pool = UlyssesPool(pools[i]);

            UlyssesPool.BandwidthState[] memory bandwidthStateList = pool.getBandwidthStateList();

            for (uint256 j = 1; j < bandwidthStateList.length; j++) {
                assets += bandwidthStateList[j].bandwidth;

                uint256 targetBandwidth = pool.totalSupply().mulDiv(bandwidthStateList[j].weight, pool.totalWeights());

                (uint64 lambda1, uint64 lambda2, uint64 sigma1, uint64 sigma2) = pool.fees();

                assets += this.calculateRebalancingFee(
                    IUlyssesPool.Fees({lambda1: lambda1, lambda2: lambda2, sigma1: sigma1, sigma2: sigma2}),
                    bandwidthStateList[j].bandwidth,
                    targetBandwidth,
                    false
                );
            }

            balances += MockERC20(pool.asset()).balanceOf(address(pool)) - pool.getProtocolFees();
            supplies += pool.totalSupply();
        }

        assertLe(assets, balances, "Assets > Balances");
        assertGe(assets, supplies, "Assets < Supplies");
    }

    function invariant_DoesNotExceedMaxDestination() public {
        UlyssesPoolHandler(handler).forEachPool(this.assertDoesNotExceedMaxDestination);
    }

    function invariant_DoesNotExceedMaxTotalWeight() public {
        UlyssesPoolHandler(handler).forEachPool(this.assertDoesNotExceedMaxTotalWeight);
    }

    function invariant_CorrectProtocolFee() public {
        UlyssesPoolHandler(handler).forEachPool(this.assertCorrectProtocolFee);
    }

    function invariant_callSummary() public view {
        UlyssesPoolHandler(handler).callSummary();
    }

    function assertDoesNotExceedMaxDestination(address pool) external {
        assertLe(UlyssesPool(pool).getBandwidthStateList().length, MAX_DESTINATIONS);
    }

    function assertDoesNotExceedMaxTotalWeight(address pool) external {
        assertLe(UlyssesPool(pool).totalWeights(), MAX_TOTAL_WEIGHT);
    }

    function assertCorrectTotalWeights(address _pool) external {
        UlyssesPool pool = UlyssesPool(_pool);

        UlyssesPool.BandwidthState[] memory bandwidthStateList = pool.getBandwidthStateList();

        uint256 weights;

        for (uint256 i = 1; i < bandwidthStateList.length; i++) {
            weights += bandwidthStateList[i].weight;
        }

        assertEq(weights, pool.totalWeights());
    }

    function assertCorrectProtocolFee(address pool) external {
        assertGe(
            UlyssesPool(pool).getProtocolFees(),
            UlyssesPoolHandler(handler).ghost_poolSwapSum(pool).mulDiv(protocolFee, DIVISIONER)
        );
        if (
            UlyssesPool(pool).getProtocolFees()
                < UlyssesPoolHandler(handler).ghost_poolSwapSum(pool).mulDiv(protocolFee, DIVISIONER)
        ) {
            revert();
        }
    }

    function assertCorrectBalance(address _pool) external {
        UlyssesPool pool = UlyssesPool(_pool);

        UlyssesPool.BandwidthState[] memory bandwidthStateList = pool.getBandwidthStateList();

        uint256 assets;
        uint256 balance;

        for (uint256 i = 1; i < bandwidthStateList.length; i++) {
            assets += bandwidthStateList[i].bandwidth;

            uint256 targetBandwidth = pool.totalSupply().mulDiv(bandwidthStateList[i].weight, pool.totalWeights());

            (uint64 lambda1, uint64 lambda2, uint64 sigma1, uint64 sigma2) = pool.fees();

            assets += this.calculateRebalancingFee(
                IUlyssesPool.Fees({lambda1: lambda1, lambda2: lambda2, sigma1: sigma1, sigma2: sigma2}),
                bandwidthStateList[i].bandwidth,
                targetBandwidth,
                false
            );
        }

        balance = MockERC20(pool.asset()).balanceOf(_pool);
        assets += pool.getProtocolFees();

        assertLe(assets, balance, "Assets > Balance");
    }

    function calculateRebalancingFee(
        IUlyssesPool.Fees memory _fees,
        uint256 bandwidth,
        uint256 targetBandwidth,
        bool roundDown
    ) public pure returns (uint256 fee) {
        if (targetBandwidth <= bandwidth) return 0;

        uint256 lowerBound1 = targetBandwidth.mulDiv(_fees.sigma1, DIVISIONER);

        if (bandwidth >= lowerBound1) {
            return 0;
        }

        uint256 lowerBound2 = targetBandwidth.mulDiv(_fees.sigma2, DIVISIONER);

        if (bandwidth >= lowerBound2) {
            uint256 maxWidth = lowerBound1 - lowerBound2;

            fee = calcFee(_fees.lambda1, maxWidth, lowerBound1, bandwidth, 0, roundDown);
        } else {
            uint256 maxWidth = lowerBound1 - lowerBound2;

            fee = calcFee(_fees.lambda1, maxWidth, lowerBound1, lowerBound2, 0, roundDown);

            fee += calcFee(_fees.lambda2, lowerBound2, lowerBound2, bandwidth, 2 * _fees.lambda1, roundDown);
        }
    }

    function calcFee(
        uint256 feeTier,
        uint256 maxWidth,
        uint256 upperBound,
        uint256 bandwidth,
        uint256 offset,
        bool roundDown
    ) public pure returns (uint256) {
        uint256 height = upperBound - bandwidth;

        uint256 width = height.mulDivUp(feeTier, maxWidth) + offset;

        return roundDown ? width.mulDiv(height, DIVISIONER) : width.mulDivUp(height, DIVISIONER);
    }
}

contract InvariantUlyssesPoolBounded is InvariantUlyssesPool {
    using FixedPointMathLib for uint256;
    using LibAddressSet for AddressSet;
    using SafeCastLib for uint256;

    function setUpHandler() public override {
        handler = address(new UlyssesPoolHandlerBounded());
    }

    function test_NegativeRebalancingFeeOnDeposit() public {
        setUpHandler();

        vm.startPrank(handler);

        UlyssesPool[] memory pools = createPools(3);
        UlyssesPool pool1 = UlyssesPool(pools[0]);
        UlyssesPool pool2 = UlyssesPool(pools[1]);
        UlyssesPool pool3 = UlyssesPool(pools[2]);

        pool1.addNewBandwidth(2, 3);
        pool1.addNewBandwidth(3, 97);

        pool2.addNewBandwidth(1, 100);

        pool3.addNewBandwidth(1, 100);

        vm.stopPrank();

        MockERC20(pool1.asset()).mint(address(this), type(uint256).max);
        MockERC20(pool1.asset()).approve(address(pool1), type(uint256).max);

        MockERC20(pool2.asset()).mint(address(this), type(uint256).max);
        MockERC20(pool2.asset()).approve(address(pool2), type(uint256).max);

        MockERC20(pool3.asset()).mint(address(this), type(uint256).max);
        MockERC20(pool3.asset()).approve(address(pool3), type(uint256).max);

        pool1.deposit(100 ether, address(this));

        pool2.swapIn(12e17, 1);
        pool3.swapIn(97 ether, 1);

        pool1.deposit(1 ether, address(this));

        invariant_CorrectBalances();
        invariant_CorrectBalance();
    }

    function test_NoNegativeRebalancingFeeOnDeposit_1() public {
        setUpHandler();

        vm.startPrank(handler);

        UlyssesPool[] memory pools = createPools(3);
        UlyssesPool pool1 = UlyssesPool(pools[0]);
        UlyssesPool pool2 = UlyssesPool(pools[1]);
        UlyssesPool pool3 = UlyssesPool(pools[2]);

        pool1.addNewBandwidth(2, 37);
        pool1.addNewBandwidth(3, 114);

        pool2.addNewBandwidth(1, 100);

        pool3.addNewBandwidth(1, 100);

        vm.stopPrank();

        MockERC20(pool1.asset()).mint(address(this), type(uint256).max);
        MockERC20(pool1.asset()).approve(address(pool1), type(uint256).max);

        MockERC20(pool2.asset()).mint(address(this), type(uint256).max);
        MockERC20(pool2.asset()).approve(address(pool2), type(uint256).max);

        MockERC20(pool3.asset()).mint(address(this), type(uint256).max);
        MockERC20(pool3.asset()).approve(address(pool3), type(uint256).max);

        pool1.deposit(86397450538600540047595985006, address(this));

        pool3.swapIn(65227214313910341492887032891, 1);
        pool1.deposit(65387863227501572279996822541, address(this));

        invariant_CorrectBalances();
        invariant_CorrectBalance();
    }

    function test_NoNegativeRebalancingFeeOnDeposit_2() public {
        setUpHandler();

        vm.startPrank(handler);

        UlyssesPool[] memory pools = createPools(3);
        UlyssesPool pool1 = UlyssesPool(pools[0]);
        UlyssesPool pool2 = UlyssesPool(pools[1]);
        UlyssesPool pool3 = UlyssesPool(pools[2]);

        pool1.addNewBandwidth(2, 3);
        pool1.addNewBandwidth(3, 97);

        pool2.addNewBandwidth(1, 100);

        pool3.addNewBandwidth(1, 100);

        vm.stopPrank();

        MockERC20(pool1.asset()).mint(address(this), type(uint256).max);
        MockERC20(pool1.asset()).approve(address(pool1), type(uint256).max);

        MockERC20(pool2.asset()).mint(address(this), type(uint256).max);
        MockERC20(pool2.asset()).approve(address(pool2), type(uint256).max);

        MockERC20(pool3.asset()).mint(address(this), type(uint256).max);
        MockERC20(pool3.asset()).approve(address(pool3), type(uint256).max);

        pool1.deposit(1000 ether, address(this));

        pool3.swapIn(700 ether, 1);

        pool1.deposit(705 ether, address(this));

        invariant_CorrectBalances();
        invariant_CorrectBalance();
    }

    function test_PoolNotInitalized() public {
        setUpHandler();

        vm.startPrank(handler);

        UlyssesPool[] memory pools = createPools(1);
        UlyssesPool pool1 = UlyssesPool(pools[0]);

        vm.stopPrank();

        MockERC20(pool1.asset()).mint(address(this), type(uint256).max);
        MockERC20(pool1.asset()).approve(address(pool1), type(uint256).max);

        vm.expectRevert(IUlyssesPool.NotInitialized.selector);
        pool1.deposit(100 ether, address(this));
    }

    function test_AmountTooSmallDeposit() public {
        setUpHandler();

        vm.startPrank(handler);

        UlyssesPool[] memory pools = createPools(2);
        UlyssesPool pool1 = UlyssesPool(pools[0]);

        pool1.addNewBandwidth(2, 100);

        vm.stopPrank();

        MockERC20(pool1.asset()).mint(address(this), type(uint256).max);
        MockERC20(pool1.asset()).approve(address(pool1), type(uint256).max);

        vm.expectRevert(IUlyssesPool.AmountTooSmall.selector);
        pool1.deposit(1, address(this));
    }

    function test_AmountTooSmallWithdraw() public {
        setUpHandler();

        vm.startPrank(handler);

        UlyssesPool[] memory pools = createPools(2);
        UlyssesPool pool1 = UlyssesPool(pools[0]);

        pool1.addNewBandwidth(2, 100);

        vm.stopPrank();

        MockERC20(pool1.asset()).mint(address(this), type(uint256).max);
        MockERC20(pool1.asset()).approve(address(pool1), type(uint256).max);

        pool1.deposit(100 ether, address(this));

        vm.expectRevert(IUlyssesPool.AmountTooSmall.selector);
        pool1.redeem(1, address(this), address(this));
    }

    function test_AmountTooSmallSwapIn() public {
        setUpHandler();

        vm.startPrank(handler);

        UlyssesPool[] memory pools = createPools(2);
        UlyssesPool pool1 = UlyssesPool(pools[0]);
        UlyssesPool pool2 = UlyssesPool(pools[1]);

        pool1.addNewBandwidth(2, 100);
        pool2.addNewBandwidth(1, 100);

        vm.stopPrank();

        MockERC20(pool1.asset()).mint(address(this), type(uint256).max);
        MockERC20(pool1.asset()).approve(address(pool1), type(uint256).max);

        MockERC20(pool2.asset()).mint(address(this), type(uint256).max);
        MockERC20(pool2.asset()).approve(address(pool2), type(uint256).max);

        pool1.deposit(100 ether, address(this));

        vm.expectRevert(IUlyssesPool.AmountTooSmall.selector);
        pool1.swapIn(1, 2);
    }

    function test_NotUlyssesLPSwapIn() public {
        setUpHandler();

        vm.startPrank(handler);

        UlyssesPool[] memory pools = createPools(1);
        UlyssesPool pool1 = UlyssesPool(pools[0]);
        vm.stopPrank();

        vm.expectRevert(IUlyssesPool.NotUlyssesLP.selector);
        pool1.swapIn(1 ether, 1);
    }

    function test_NotUlyssesLPSwapFromPool() public {
        setUpHandler();

        vm.startPrank(handler);

        UlyssesPool[] memory pools = createPools(1);
        UlyssesPool pool1 = UlyssesPool(pools[0]);
        vm.stopPrank();

        vm.expectRevert(IUlyssesPool.NotUlyssesLP.selector);
        pool1.swapFromPool(1 ether, address(this));
    }
}
