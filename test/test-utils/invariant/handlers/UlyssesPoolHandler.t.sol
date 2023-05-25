// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console2} from "forge-std/console2.sol";

import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {UlyssesPool, IUlyssesPool, UlyssesERC4626} from "@ulysses-amm/UlyssesPool.sol";

import {InvariantUlyssesPool} from "@test/ulysses-amm/UlyssesPoolTest.t.sol";

import {AddressSet, LibAddressSet} from "../helpers/AddressSet.sol";

contract UlyssesPoolHandler is CommonBase, StdCheats, StdUtils {
    using LibAddressSet for AddressSet;
    using FixedPointMathLib for uint256;
    using SafeCastLib for uint256;

    address public owner = address(this);

    uint256 public ghost_depositSum;
    uint256 public ghost_withdrawSum;
    uint256 public ghost_swapSum;
    uint256 public ghost_forcePushSum;

    uint256 public ghost_zeroDeposits;
    uint256 public ghost_zeroWithdrawals;
    uint256 public ghost_zeroSwaps;
    uint256 public ghost_zeroAddDestinations;
    uint256 public ghost_zeroTransfers;
    uint256 public ghost_zeroTransferFroms;

    mapping(address => uint256) public ghost_poolSwapSum;

    mapping(bytes32 => uint256) public calls;

    AddressSet internal _actors;
    address internal currentActor;

    AddressSet internal _pools;
    UlyssesPool internal currentSourcePool;
    UlyssesPool internal currentDestinationPool;

    /// @notice The minimum amount that can be swapped
    uint256 internal constant MIN_SWAP_AMOUNT = 10002;

    uint256 constant MAX_DEPOSIT = type(uint96).max;

    uint256 constant MAX_TOTAL_WEIGHT = 256;

    uint256 constant MAX_DESTINATIONS = 15;

    InvariantUlyssesPool internal invariantPoolTest;

    modifier createActor() {
        currentActor = msg.sender;
        _actors.add(msg.sender);
        vm.stopPrank();
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    modifier useActor(uint256 actorIndexSeed) {
        currentActor = _actors.rand(actorIndexSeed);
        vm.stopPrank();
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    modifier useSourcePool(uint256 poolIndexSeed) {
        currentSourcePool = UlyssesPool(_pools.rand(poolIndexSeed));
        _;
    }

    modifier useDestinationPool(uint256 poolIndexSeed) {
        currentDestinationPool = UlyssesPool(_pools.rand(poolIndexSeed));
        _;
    }

    modifier countCall(bytes32 key) {
        calls[key]++;
        _;
    }

    constructor() {
        invariantPoolTest = InvariantUlyssesPool(msg.sender);
    }

    function addPool(UlyssesPool pool) public {
        _pools.add(address(pool));
    }

    function getMinimumBandwidth(UlyssesPool pool) internal view returns (uint256 minimum) {
        minimum = type(uint256).max;

        for (uint256 i = 1; i < pool.getBandwidthStateList().length; i++) {
            minimum = minimum.min(pool.getBandwidthStateList()[i].bandwidth);
        }
    }

    function claimProtocolFees(uint256 poolSeed)
        public
        virtual
        useSourcePool(poolSeed)
        countCall("claimProtocolFees")
    {
        currentSourcePool.claimProtocolFees();
        ghost_poolSwapSum[address(currentSourcePool)] = 0;
    }

    function addNewBandwidth(uint256 sourcePoolSeed, uint256 destinationPoolSeed, uint8 weight)
        public
        virtual
        useSourcePool(sourcePoolSeed)
        useDestinationPool(destinationPoolSeed)
        countCall("addNewBandwidth")
    {
        _mintAndApprovePoolAsset(currentSourcePool, address(this), 1000 ether);

        currentSourcePool.addNewBandwidth(currentDestinationPool.id(), weight);

        currentDestinationPool.addNewBandwidth(currentSourcePool.id(), weight);
    }

    function deposit(uint256 poolSeed, uint256 assets)
        public
        virtual
        createActor
        useSourcePool(poolSeed)
        countCall("deposit")
    {
        _mintAndApprovePoolAsset(currentSourcePool, currentActor, assets);

        currentSourcePool.deposit(assets, currentActor);

        ghost_depositSum += assets;
    }

    function mint(uint256 poolSeed, uint256 shares)
        public
        virtual
        createActor
        useSourcePool(poolSeed)
        countCall("mint")
    {
        _mintAndApprovePoolAsset(currentSourcePool, currentActor, shares);

        currentSourcePool.mint(shares, currentActor);

        ghost_depositSum += shares;
    }

    function redeem(uint256 poolSeed, uint256 actorSeed, uint256 shares)
        public
        virtual
        useActor(actorSeed)
        useSourcePool(poolSeed)
        countCall("redeem")
    {
        currentSourcePool.redeem(shares, currentActor, currentActor);

        ghost_withdrawSum += shares;
    }

    function swapIn(uint256 actorSeed, uint256 sourcePoolSeed, uint256 destinationPoolSeed, uint256 amount)
        public
        virtual
        // createActor
        useActor(actorSeed)
        useSourcePool(sourcePoolSeed)
        useDestinationPool(destinationPoolSeed)
        countCall("swapIn")
    {
        _mintAndApprovePoolAsset(currentSourcePool, currentActor, amount);

        currentSourcePool.swapIn(amount, currentDestinationPool.id());

        ghost_swapSum += amount;
        ghost_poolSwapSum[address(currentSourcePool)] += amount;
    }

    function forEachActor(function(address) external func) public {
        return _actors.forEach(func);
    }

    function forEachPool(function(address) external func) public {
        return _pools.forEach(func);
    }

    function reduceActors(uint256 acc, function(uint256, address) external returns (uint256) func)
        public
        returns (uint256)
    {
        return _actors.reduce(acc, func);
    }

    function reducePools(uint256 pool, function(uint256, address) external returns (uint256) func)
        public
        returns (uint256)
    {
        return _pools.reduce(pool, func);
    }

    function actors() external view returns (address[] memory) {
        return _actors.addrs;
    }

    function pools() external view returns (address[] memory) {
        return _pools.addrs;
    }

    function callSummary() external view {
        console2.log("Call summary:");
        console2.log("-------------------");
        console2.log("claimProtocolFees", calls["claimProtocolFees"]);
        console2.log("addNewBandwidth", calls["addNewBandwidth"]);
        console2.log("deposit", calls["deposit"]);
        console2.log("mint", calls["mint"]);
        console2.log("withdraw", calls["withdraw"]);
        console2.log("redeem", calls["redeem"]);
        console2.log("swapIn", calls["swapIn"]);
        console2.log("-------------------");

        console2.log("Deposits Sum: \t", ghost_depositSum);
        console2.log("withdrawals Sum: \t", ghost_withdrawSum);
        console2.log("Swaps Sum: \t\t", ghost_swapSum);
        console2.log("-------------------");

        console2.log("Zero AddDestinations:", ghost_zeroAddDestinations);
        console2.log("Zero Deposits:", ghost_zeroDeposits);
        console2.log("Zero withdrawals:", ghost_zeroWithdrawals);
        console2.log("Zero Swaps:", ghost_zeroSwaps);
    }

    function _pay(address to, uint256 amount) internal {
        (bool s,) = to.call{value: amount}("");
        require(s, "pay() failed");
    }

    function _mintAndApprovePoolAsset(UlyssesPool _pool, address to, uint256 amount) internal {
        MockERC20 token = MockERC20(address(_pool.asset()));
        token.mint(to, amount);
        token.approve(address(_pool), amount);
    }
}

contract UlyssesPoolHandlerBounded is UlyssesPoolHandler {
    using LibAddressSet for AddressSet;
    using FixedPointMathLib for uint256;
    using SafeCastLib for uint256;

    function claimProtocolFees(uint256 poolSeed)
        public
        override
        useSourcePool(poolSeed)
        countCall("claimProtocolFees")
    {
        currentSourcePool.claimProtocolFees();
        ghost_poolSwapSum[address(currentSourcePool)] = 0;
    }

    function addNewBandwidth(uint256 sourcePoolSeed, uint256 destinationPoolSeed, uint8 weight)
        public
        override
        useSourcePool(sourcePoolSeed)
        useDestinationPool(destinationPoolSeed)
        countCall("addNewBandwidth")
    {
        UlyssesPool pool = currentDestinationPool;
        do {
            unchecked {
                ++destinationPoolSeed;
            }
            pool = UlyssesPool(_pools.rand(destinationPoolSeed));
        } while (
            (pool == currentSourcePool || currentSourcePool.destinationIds(address(pool)) != 0)
                && pool != currentDestinationPool
        );
        currentDestinationPool = pool;

        if (
            pool == currentSourcePool || currentSourcePool.destinationIds(address(currentDestinationPool)) != 0
                || currentSourcePool.getBandwidthStateList().length >= MAX_DESTINATIONS
                || MAX_TOTAL_WEIGHT - currentSourcePool.totalWeights() == 0
                || currentDestinationPool.destinationIds(address(currentSourcePool)) != 0
                || currentDestinationPool.getBandwidthStateList().length >= MAX_DESTINATIONS
                || MAX_TOTAL_WEIGHT - currentDestinationPool.totalWeights() == 0
        ) {
            ghost_zeroAddDestinations++;
            return;
        }

        uint8 weightSource = bound(weight, 1, MAX_TOTAL_WEIGHT - currentSourcePool.totalWeights()).toUint8();

        _mintAndApprovePoolAsset(currentSourcePool, address(this), 50 ether);
        _mintAndApprovePoolAsset(currentDestinationPool, address(this), 50 ether);

        currentSourcePool.addNewBandwidth(currentDestinationPool.id(), weightSource);

        uint8 weightDestination = bound(weight, 1, MAX_TOTAL_WEIGHT - currentDestinationPool.totalWeights()).toUint8();

        currentDestinationPool.addNewBandwidth(currentSourcePool.id(), weightDestination);
    }

    function deposit(uint256 poolSeed, uint256 assets)
        public
        override
        createActor
        useSourcePool(poolSeed)
        countCall("deposit")
    {
        if (currentSourcePool.getBandwidthStateList().length == 1) {
            ghost_zeroDeposits++;
            return;
        }

        assets = bound(assets, MIN_SWAP_AMOUNT, MAX_DEPOSIT);

        _mintAndApprovePoolAsset(currentSourcePool, currentActor, assets);

        ghost_depositSum += assets;
    }

    function mint(uint256 poolSeed, uint256 shares)
        public
        override
        createActor
        useSourcePool(poolSeed)
        countCall("mint")
    {
        if (currentSourcePool.getBandwidthStateList().length == 1) {
            ghost_zeroDeposits++;
            return;
        }

        shares = bound(shares, MIN_SWAP_AMOUNT, MAX_DEPOSIT);

        _mintAndApprovePoolAsset(
            currentSourcePool, currentActor, shares + currentSourcePool.getBandwidthStateList().length - 1
        );

        currentSourcePool.mint(shares, currentActor);

        ghost_depositSum += shares;
    }

    function redeem(uint256 poolSeed, uint256 actorSeed, uint256 shares)
        public
        override
        useActor(actorSeed)
        useSourcePool(poolSeed)
        countCall("redeem")
    {
        uint256 balanceToWithdraw = currentSourcePool.balanceOf(currentActor);

        if (
            balanceToWithdraw == 0 || balanceToWithdraw < MIN_SWAP_AMOUNT
                || currentSourcePool.getBandwidthStateList().length == 1
        ) {
            ghost_zeroWithdrawals++;
            return;
        }

        shares = bound(shares, MIN_SWAP_AMOUNT, balanceToWithdraw);

        currentSourcePool.redeem(shares, currentActor, currentActor);

        ghost_withdrawSum += shares;
    }

    function swapIn(uint256 actorSeed, uint256 sourcePoolSeed, uint256 destinationPoolSeed, uint256 amount)
        public
        override
        // createActor
        useActor(actorSeed)
        useSourcePool(sourcePoolSeed)
        useDestinationPool(destinationPoolSeed)
        countCall("swapIn")
    {
        if (UlyssesPool(currentSourcePool).getBandwidth(UlyssesPool(currentDestinationPool).id()) == 0) {
            ghost_zeroSwaps++;
            return;
        }

        uint256 maxSwap = currentDestinationPool.getBandwidth(currentSourcePool.id());

        if (maxSwap < MIN_SWAP_AMOUNT) {
            ghost_zeroSwaps++;
            return;
        }

        amount = bound(amount, MIN_SWAP_AMOUNT, maxSwap);

        _mintAndApprovePoolAsset(currentSourcePool, currentActor, amount);

        currentSourcePool.swapIn(amount, currentDestinationPool.id());

        ghost_swapSum += amount;
        ghost_poolSwapSum[address(currentSourcePool)] += amount;
    }
}
