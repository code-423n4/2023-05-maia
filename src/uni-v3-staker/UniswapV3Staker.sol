// SPDX-License-Identifier: MIT
// Rewards logic inspired by Uniswap V3 Contracts (Uniswap/v3-staker/contracts/UniswapV3Staker.sol)
pragma solidity ^0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {Multicallable} from "solady/utils/Multicallable.sol";

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {IUniswapV3GaugeFactory} from "@gauges/interfaces/IUniswapV3GaugeFactory.sol";
import {UniswapV3Gauge} from "@gauges/UniswapV3Gauge.sol";
import {bHermesBoost} from "@hermes/tokens/bHermesBoost.sol";

import {IncentiveId} from "./libraries/IncentiveId.sol";
import {IncentiveTime} from "./libraries/IncentiveTime.sol";
import {NFTPositionInfo} from "./libraries/NFTPositionInfo.sol";
import {RewardMath} from "./libraries/RewardMath.sol";

import {IUniswapV3Staker} from "./interfaces/IUniswapV3Staker.sol";

/// @title Uniswap V3 Staker Interface with bHermes Boost.
contract UniswapV3Staker is IUniswapV3Staker, Multicallable {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                        UNISWAP V3 STAKER STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IUniswapV3Staker
    mapping(address => IUniswapV3Pool) public gaugePool;

    /// @inheritdoc IUniswapV3Staker
    mapping(IUniswapV3Pool => UniswapV3Gauge) public gauges;

    /// @inheritdoc IUniswapV3Staker
    mapping(IUniswapV3Pool => address) public bribeDepots;

    /// @inheritdoc IUniswapV3Staker
    mapping(IUniswapV3Pool => uint24) public poolsMinimumWidth;

    /// @inheritdoc IUniswapV3Staker
    mapping(bytes32 => Incentive) public override incentives;

    /// @inheritdoc IUniswapV3Staker
    mapping(uint256 => Deposit) public override deposits;

    /// @notice stakes[user][pool] => tokenId of attached position of user per pool
    mapping(address => mapping(IUniswapV3Pool => uint256)) private _userAttachements;

    /// @dev stakes[tokenId][incentiveHash] => Stake
    mapping(uint256 => mapping(bytes32 => Stake)) private _stakes;

    /// @dev stakedIncentives[tokenId] => incentiveIds
    mapping(uint256 => IncentiveKey) private stakedIncentiveKey;

    /// @inheritdoc IUniswapV3Staker
    function stakes(uint256 tokenId, bytes32 incentiveId)
        public
        view
        override
        returns (uint160 secondsPerLiquidityInsideInitialX128, uint128 liquidity)
    {
        Stake storage stake = _stakes[tokenId][incentiveId];
        secondsPerLiquidityInsideInitialX128 = stake.secondsPerLiquidityInsideInitialX128;
        liquidity = stake.liquidityNoOverflow;
        if (liquidity == type(uint96).max) {
            liquidity = stake.liquidityIfOverflow;
        }
    }

    /// @inheritdoc IUniswapV3Staker
    function userAttachements(address user, IUniswapV3Pool pool) external view override returns (uint256) {
        return hermesGaugeBoost.isUserGauge(user, address(gauges[pool])) ? _userAttachements[user][pool] : 0;
    }

    /// @inheritdoc IUniswapV3Staker
    mapping(address => uint256) public override rewards;

    /// @inheritdoc IUniswapV3Staker
    mapping(uint256 => uint256) public tokenIdRewards;

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The address of the Uniswap V3 Gauge Factory
    IUniswapV3GaugeFactory public immutable uniswapV3GaugeFactory;

    /// @inheritdoc IUniswapV3Staker
    IUniswapV3Factory public immutable override factory;

    /// @inheritdoc IUniswapV3Staker
    INonfungiblePositionManager public immutable override nonfungiblePositionManager;

    /// @inheritdoc IUniswapV3Staker
    uint256 public immutable override maxIncentiveStartLeadTime;

    /// @inheritdoc IUniswapV3Staker
    address public immutable minter;

    /// @inheritdoc IUniswapV3Staker
    address public immutable hermes;

    /// @inheritdoc IUniswapV3Staker
    bHermesBoost public immutable hermesGaugeBoost;

    /// @param _factory the Uniswap V3 factory
    /// @param _nonfungiblePositionManager the NFT position manager contract address
    /// @param _maxIncentiveStartLeadTime the max duration of an incentive in seconds
    constructor(
        IUniswapV3Factory _factory,
        INonfungiblePositionManager _nonfungiblePositionManager,
        IUniswapV3GaugeFactory _uniswapV3GaugeFactory,
        bHermesBoost _hermesGaugeBoost,
        uint256 _maxIncentiveStartLeadTime,
        address _minter,
        address _hermes
    ) {
        factory = _factory;
        nonfungiblePositionManager = _nonfungiblePositionManager;
        maxIncentiveStartLeadTime = _maxIncentiveStartLeadTime;
        uniswapV3GaugeFactory = _uniswapV3GaugeFactory;
        hermesGaugeBoost = _hermesGaugeBoost;
        minter = _minter;
        hermes = _hermes;
    }

    /*//////////////////////////////////////////////////////////////
                        CREATE INCENTIVE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IUniswapV3Staker
    function createIncentiveFromGauge(uint256 reward) external {
        if (reward <= 0) revert IncentiveRewardMustBePositive();

        uint96 startTime = IncentiveTime.computeEnd(block.timestamp);

        IUniswapV3Pool pool = gaugePool[msg.sender];

        if (address(pool) == address(0)) revert IncentiveCallerMustBeRegisteredGauge();

        IncentiveKey memory key = IncentiveKey({startTime: startTime, pool: pool});
        bytes32 incentiveId = IncentiveId.compute(key);

        incentives[incentiveId].totalRewardUnclaimed += reward;

        hermes.safeTransferFrom(msg.sender, address(this), reward);

        emit IncentiveCreated(pool, startTime, reward);
    }

    /// @inheritdoc IUniswapV3Staker
    function createIncentive(IncentiveKey memory key, uint256 reward) external {
        if (reward <= 0) revert IncentiveRewardMustBePositive();

        uint96 startTime = IncentiveTime.computeStart(key.startTime);

        if (startTime != key.startTime) revert IncentiveStartTimeNotAtEndOfAnEpoch();

        if (startTime <= block.timestamp) revert IncentiveStartTimeMustBeNowOrInTheFuture();
        if (startTime - block.timestamp > maxIncentiveStartLeadTime) {
            revert IncentiveStartTimeTooFarIntoFuture();
        }

        if (address(gauges[key.pool]) == address(0)) {
            revert IncentiveCannotBeCreatedForPoolWithNoGauge();
        }

        bytes32 incentiveId = IncentiveId.compute(key);

        incentives[incentiveId].totalRewardUnclaimed += reward;

        hermes.safeTransferFrom(msg.sender, address(this), reward);

        emit IncentiveCreated(key.pool, startTime, reward);
    }

    /*//////////////////////////////////////////////////////////////
                            END INCENTIVE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IUniswapV3Staker
    function endIncentive(IncentiveKey memory key) external returns (uint256 refund) {
        if (block.timestamp < IncentiveTime.getEnd(key.startTime)) {
            revert EndIncentiveBeforeEndTime();
        }

        bytes32 incentiveId = IncentiveId.compute(key);

        Incentive storage incentive = incentives[incentiveId];

        refund = incentive.totalRewardUnclaimed;

        if (refund == 0) revert EndIncentiveNoRefundAvailable();
        if (incentive.numberOfStakes > 0) revert EndIncentiveWhileStakesArePresent();

        // issue the refund
        incentive.totalRewardUnclaimed = 0;

        hermes.safeTransfer(minter, refund);

        // note we never clear totalSecondsClaimedX128

        emit IncentiveEnded(incentiveId, refund);
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT TOKEN LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Upon receiving a Uniswap V3 ERC721, create the token deposit and
    ///      _stakes in current incentive setting owner to `from`.
    /// @inheritdoc IERC721Receiver
    function onERC721Received(address, address from, uint256 tokenId, bytes calldata)
        external
        override
        returns (bytes4)
    {
        INonfungiblePositionManager _nonfungiblePositionManager = nonfungiblePositionManager;
        if (msg.sender != address(_nonfungiblePositionManager)) revert TokenNotUniswapV3NFT();

        (IUniswapV3Pool pool, int24 tickLower, int24 tickUpper, uint128 liquidity) =
            NFTPositionInfo.getPositionInfo(factory, nonfungiblePositionManager, tokenId);

        deposits[tokenId] = Deposit({owner: from, tickLower: tickLower, tickUpper: tickUpper, stakedTimestamp: 0});
        emit DepositTransferred(tokenId, address(0), from);

        // stake the token in the current incentive
        _stakeToken(tokenId, pool, tickLower, tickUpper, liquidity);

        return this.onERC721Received.selector;
    }

    /*//////////////////////////////////////////////////////////////
                            WITHDRAW TOKEN LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IUniswapV3Staker
    function withdrawToken(uint256 tokenId, address to, bytes memory data) external {
        if (to == address(0)) revert InvalidRecipient();

        Deposit storage deposit = deposits[tokenId];

        if (deposit.owner != msg.sender) revert NotCalledByOwner();
        if (deposit.stakedTimestamp != 0) revert TokenStakedError();

        delete deposits[tokenId];
        emit DepositTransferred(tokenId, msg.sender, address(0));

        nonfungiblePositionManager.safeTransferFrom(address(this), to, tokenId, data);
    }

    /*//////////////////////////////////////////////////////////////
                            REWARD LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IUniswapV3Staker
    function claimReward(address to, uint256 amountRequested) external returns (uint256 reward) {
        reward = rewards[msg.sender];
        if (amountRequested != 0 && amountRequested < reward) {
            reward = amountRequested;
            rewards[msg.sender] -= reward;
        } else {
            rewards[msg.sender] = 0;
        }

        if (reward > 0) hermes.safeTransfer(to, reward);

        emit RewardClaimed(to, reward);
    }

    /// @inheritdoc IUniswapV3Staker
    function claimAllRewards(address to) external returns (uint256 reward) {
        reward = rewards[msg.sender];
        rewards[msg.sender] = 0;

        if (reward > 0) hermes.safeTransfer(to, reward);

        emit RewardClaimed(to, reward);
    }

    /// @inheritdoc IUniswapV3Staker
    function getRewardInfo(IncentiveKey memory key, uint256 tokenId)
        external
        view
        override
        returns (uint256 reward, uint160 secondsInsideX128)
    {
        Deposit storage deposit = deposits[tokenId];

        (uint96 endTime, uint256 stakedDuration) =
            IncentiveTime.getEndAndDuration(key.startTime, deposit.stakedTimestamp, block.timestamp);

        bytes32 incentiveId = IncentiveId.compute(key);
        {
            uint128 boostAmount;
            uint128 boostTotalSupply;
            address owner = deposit.owner;
            // If tokenId is attached to gauge
            if (_userAttachements[owner][key.pool] == tokenId) {
                // get boost amount and total supply
                (boostAmount, boostTotalSupply) = hermesGaugeBoost.getUserGaugeBoost(owner, address(gauges[key.pool]));
            }

            (uint160 secondsPerLiquidityInsideInitialX128, uint128 liquidity) = stakes(tokenId, incentiveId);
            if (liquidity == 0) revert TokenNotStaked();

            (, uint160 secondsPerLiquidityInsideX128,) =
                key.pool.snapshotCumulativesInside(deposit.tickLower, deposit.tickUpper);

            secondsInsideX128 = RewardMath.computeBoostedSecondsInsideX128(
                stakedDuration,
                liquidity,
                uint128(boostAmount),
                uint128(boostTotalSupply),
                secondsPerLiquidityInsideInitialX128,
                secondsPerLiquidityInsideX128
            );
        }

        Incentive storage incentive = incentives[incentiveId];
        reward = RewardMath.computeBoostedRewardAmount(
            incentive.totalRewardUnclaimed,
            incentive.totalSecondsClaimedX128,
            key.startTime,
            endTime,
            secondsInsideX128,
            block.timestamp
        );
    }

    /*//////////////////////////////////////////////////////////////
                            RE-STAKE TOKEN LOGIC
    //////////////////////////////////////////////////////////////*/

    function restakeToken(uint256 tokenId) external {
        IncentiveKey storage incentiveId = stakedIncentiveKey[tokenId];
        if (incentiveId.startTime != 0) _unstakeToken(incentiveId, tokenId, true);

        (IUniswapV3Pool pool, int24 tickLower, int24 tickUpper, uint128 liquidity) =
            NFTPositionInfo.getPositionInfo(factory, nonfungiblePositionManager, tokenId);

        _stakeToken(tokenId, pool, tickLower, tickUpper, liquidity);
    }

    /*//////////////////////////////////////////////////////////////
                            UNSTAKE TOKEN LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IUniswapV3Staker
    function unstakeToken(uint256 tokenId) external {
        IncentiveKey storage incentiveId = stakedIncentiveKey[tokenId];
        if (incentiveId.startTime != 0) _unstakeToken(incentiveId, tokenId, true);
    }

    /// @inheritdoc IUniswapV3Staker
    function unstakeToken(IncentiveKey memory key, uint256 tokenId) external {
        _unstakeToken(key, tokenId, true);
    }

    function _unstakeToken(IncentiveKey memory key, uint256 tokenId, bool isNotRestake) private {
        Deposit storage deposit = deposits[tokenId];

        (uint96 endTime, uint256 stakedDuration) =
            IncentiveTime.getEndAndDuration(key.startTime, deposit.stakedTimestamp, block.timestamp);

        address owner = deposit.owner;

        // anyone can call restakeToken if the block time is after the end time of the incentive
        if ((isNotRestake || block.timestamp < endTime) && owner != msg.sender) revert NotCalledByOwner();

        {
            // scope for bribeAddress, avoids stack too deep errors
            address bribeAddress = bribeDepots[key.pool];

            if (bribeAddress != address(0)) {
                nonfungiblePositionManager.collect(
                    INonfungiblePositionManager.CollectParams({
                        tokenId: tokenId,
                        recipient: bribeAddress,
                        amount0Max: type(uint128).max,
                        amount1Max: type(uint128).max
                    })
                );
            }
        }

        bytes32 incentiveId = IncentiveId.compute(key);
        uint160 secondsInsideX128;
        uint128 liquidity;
        {
            uint128 boostAmount;
            uint128 boostTotalSupply;

            UniswapV3Gauge gauge = gauges[key.pool]; // saves another SLOAD if no tokenId is attached

            // If tokenId is attached to gauge
            if (hermesGaugeBoost.isUserGauge(owner, address(gauge)) && _userAttachements[owner][key.pool] == tokenId) {
                // get boost amount and total supply
                (boostAmount, boostTotalSupply) = hermesGaugeBoost.getUserGaugeBoost(owner, address(gauge));
                gauge.detachUser(owner);
                _userAttachements[owner][key.pool] = 0;
            }

            uint160 secondsPerLiquidityInsideInitialX128;
            (secondsPerLiquidityInsideInitialX128, liquidity) = stakes(tokenId, incentiveId);
            if (liquidity == 0) revert TokenNotStaked();

            (, uint160 secondsPerLiquidityInsideX128,) =
                key.pool.snapshotCumulativesInside(deposit.tickLower, deposit.tickUpper);

            secondsInsideX128 = RewardMath.computeBoostedSecondsInsideX128(
                stakedDuration,
                liquidity,
                uint128(boostAmount),
                uint128(boostTotalSupply),
                secondsPerLiquidityInsideInitialX128,
                secondsPerLiquidityInsideX128
            );
        }

        deposit.stakedTimestamp = 0;
        Incentive storage incentive = incentives[incentiveId];
        incentive.numberOfStakes--;
        uint256 reward = RewardMath.computeBoostedRewardAmount(
            incentive.totalRewardUnclaimed,
            incentive.totalSecondsClaimedX128,
            key.startTime,
            endTime,
            secondsInsideX128,
            block.timestamp
        );

        unchecked {
            // if this overflows, e.g. after 2^32-1 full liquidity seconds have been claimed,
            // reward rate will fall drastically so it's safe
            // can't overflow if incentiveDuration < 2^32-1 seconds
            incentive.totalSecondsClaimedX128 += secondsInsideX128;
            // reward is never greater than total reward unclaimed
            incentive.totalRewardUnclaimed -= reward;
            // this only overflows if a token has a total supply greater than type(uint256).max
            rewards[owner] += reward;

            // this only overflows if a token has a total supply greater than type(uint256).max
            // Accounting purposes for external contracts only
            tokenIdRewards[tokenId] += reward;
        }

        Stake storage stake = _stakes[tokenId][incentiveId];
        stake.secondsPerLiquidityInsideInitialX128 = 0;
        stake.liquidityNoOverflow = 0;
        if (liquidity >= type(uint96).max) stake.liquidityIfOverflow = 0;
        delete stakedIncentiveKey[tokenId];
        emit TokenUnstaked(tokenId, incentiveId);
    }

    /*//////////////////////////////////////////////////////////////
                            STAKE TOKEN LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IUniswapV3Staker
    function stakeToken(uint256 tokenId) external override {
        if (deposits[tokenId].stakedTimestamp != 0) revert TokenStakedError();

        (IUniswapV3Pool pool, int24 tickLower, int24 tickUpper, uint128 liquidity) =
            NFTPositionInfo.getPositionInfo(factory, nonfungiblePositionManager, tokenId);

        _stakeToken(tokenId, pool, tickLower, tickUpper, liquidity);
    }

    /// @dev Stakes a deposited token without doing an already staked in another position check
    function _stakeToken(uint256 tokenId, IUniswapV3Pool pool, int24 tickLower, int24 tickUpper, uint128 liquidity)
        private
    {
        IncentiveKey memory key = IncentiveKey({pool: pool, startTime: IncentiveTime.computeStart(block.timestamp)});

        bytes32 incentiveId = IncentiveId.compute(key);

        if (incentives[incentiveId].totalRewardUnclaimed == 0) revert NonExistentIncentiveError();

        if (uint24(tickUpper - tickLower) < poolsMinimumWidth[pool]) revert RangeTooSmallError();
        if (liquidity == 0) revert NoLiquidityError();

        stakedIncentiveKey[tokenId] = key;

        // If user not attached to gauge, attach
        address tokenOwner = deposits[tokenId].owner;
        if (tokenOwner == address(0)) revert TokenNotDeposited();

        UniswapV3Gauge gauge = gauges[pool]; // saves another SLOAD if no tokenId is attached

        if (!hermesGaugeBoost.isUserGauge(tokenOwner, address(gauge))) {
            _userAttachements[tokenOwner][pool] = tokenId;
            gauge.attachUser(tokenOwner);
        }

        deposits[tokenId].stakedTimestamp = uint40(block.timestamp);
        incentives[incentiveId].numberOfStakes++;

        (, uint160 secondsPerLiquidityInsideX128,) = pool.snapshotCumulativesInside(tickLower, tickUpper);

        if (liquidity >= type(uint96).max) {
            _stakes[tokenId][incentiveId] = Stake({
                secondsPerLiquidityInsideInitialX128: secondsPerLiquidityInsideX128,
                liquidityNoOverflow: type(uint96).max,
                liquidityIfOverflow: liquidity
            });
        } else {
            Stake storage stake = _stakes[tokenId][incentiveId];
            stake.secondsPerLiquidityInsideInitialX128 = secondsPerLiquidityInsideX128;
            stake.liquidityNoOverflow = uint96(liquidity);
        }

        emit TokenStaked(tokenId, incentiveId, liquidity);
    }

    /*//////////////////////////////////////////////////////////////
                        GAUGE UPDATE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IUniswapV3Staker
    function updateGauges(IUniswapV3Pool uniswapV3Pool) external {
        address uniswapV3Gauge = address(uniswapV3GaugeFactory.strategyGauges(address(uniswapV3Pool)));

        if (uniswapV3Gauge == address(0)) revert InvalidGauge();

        if (address(gauges[uniswapV3Pool]) != uniswapV3Gauge) {
            emit GaugeUpdated(uniswapV3Pool, uniswapV3Gauge);

            gauges[uniswapV3Pool] = UniswapV3Gauge(uniswapV3Gauge);
            gaugePool[uniswapV3Gauge] = uniswapV3Pool;
        }

        updateBribeDepot(uniswapV3Pool);
        updatePoolMinimumWidth(uniswapV3Pool);
    }

    /// @inheritdoc IUniswapV3Staker
    function updateBribeDepot(IUniswapV3Pool uniswapV3Pool) public {
        address newDepot = address(gauges[uniswapV3Pool].multiRewardsDepot());
        if (newDepot != bribeDepots[uniswapV3Pool]) {
            bribeDepots[uniswapV3Pool] = newDepot;

            emit BribeDepotUpdated(uniswapV3Pool, newDepot);
        }
    }

    /// @inheritdoc IUniswapV3Staker
    function updatePoolMinimumWidth(IUniswapV3Pool uniswapV3Pool) public {
        uint24 minimumWidth = gauges[uniswapV3Pool].minimumWidth();
        if (minimumWidth != poolsMinimumWidth[uniswapV3Pool]) {
            poolsMinimumWidth[uniswapV3Pool] = minimumWidth;

            emit PoolMinimumWidthUpdated(uniswapV3Pool, minimumWidth);
        }
    }
}
