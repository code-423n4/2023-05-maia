// SPDX-License-Identifier: MIT
// Rewards logic inspired by Tribe DAO Contracts (flywheel-v2/src/rewards/FlywheelGaugeRewards.sol)
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {ERC20Gauges} from "@ERC20/ERC20Gauges.sol";

import {IFlywheelGaugeRewards} from "../interfaces/IFlywheelGaugeRewards.sol";

import {IBaseV2Minter} from "@hermes/interfaces/IBaseV2Minter.sol";

/// @title Flywheel Gauge Reward Stream
contract FlywheelGaugeRewards is Ownable, IFlywheelGaugeRewards {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;

    /*//////////////////////////////////////////////////////////////
                        REWARDS CONTRACT STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFlywheelGaugeRewards
    ERC20Gauges public immutable override gaugeToken;

    /// @notice the minter contract, is a rewardsStream to collect rewards from
    IBaseV2Minter public immutable minter;

    /// @inheritdoc IFlywheelGaugeRewards
    address public immutable override rewardToken;

    /// @inheritdoc IFlywheelGaugeRewards
    uint32 public override gaugeCycle;

    /// @inheritdoc IFlywheelGaugeRewards
    uint32 public immutable override gaugeCycleLength;

    /// @inheritdoc IFlywheelGaugeRewards
    mapping(ERC20 => QueuedRewards) public override gaugeQueuedRewards;

    /// @notice the start of the next cycle being partially queued
    uint32 internal nextCycle;

    // rewards that made it into a partial queue but didn't get completed
    uint112 internal nextCycleQueuedRewards;

    // the offset during pagination of the queue
    uint32 internal paginationOffset;

    constructor(address _rewardToken, address _owner, ERC20Gauges _gaugeToken, IBaseV2Minter _minter) {
        _initializeOwner(_owner);
        rewardToken = _rewardToken;

        gaugeCycleLength = _gaugeToken.gaugeCycleLength();

        // seed initial gaugeCycle
        gaugeCycle = (block.timestamp.toUint32() / gaugeCycleLength) * gaugeCycleLength;

        gaugeToken = _gaugeToken;

        minter = _minter;
    }

    /*//////////////////////////////////////////////////////////////
                        GAUGE REWARDS LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFlywheelGaugeRewards
    function queueRewardsForCycle() external returns (uint256 totalQueuedForCycle) {
        /// @dev Update minter cycle and queue rewars if needed.
        /// This will make this call fail if it is a new epoch, because the minter calls this function, the first call would fail with "CycleError()".
        /// Should be called through Minter to kickoff new epoch.
        minter.updatePeriod();

        // next cycle is always the next even divisor of the cycle length above current block timestamp.
        uint32 currentCycle = (block.timestamp.toUint32() / gaugeCycleLength) * gaugeCycleLength;
        uint32 lastCycle = gaugeCycle;

        // ensure new cycle has begun
        if (currentCycle <= lastCycle) revert CycleError();

        gaugeCycle = currentCycle;

        // queue the rewards stream and sanity check the tokens were received
        uint256 balanceBefore = rewardToken.balanceOf(address(this));
        totalQueuedForCycle = minter.getRewards();
        require(rewardToken.balanceOf(address(this)) - balanceBefore >= totalQueuedForCycle);

        // include uncompleted cycle
        totalQueuedForCycle += nextCycleQueuedRewards;

        // iterate over all gauges and update the rewards allocations
        address[] memory gauges = gaugeToken.gauges();

        _queueRewards(gauges, currentCycle, lastCycle, totalQueuedForCycle);

        nextCycleQueuedRewards = 0;
        paginationOffset = 0;

        emit CycleStart(currentCycle, totalQueuedForCycle);
    }

    /// @inheritdoc IFlywheelGaugeRewards
    function queueRewardsForCyclePaginated(uint256 numRewards) external {
        /// @dev Update minter cycle and queue rewars if needed.
        /// This will make this call fail if it is a new epoch, because the minter calls this function, the first call would fail with "CycleError()".
        /// Should be called through Minter to kickoff new epoch.
        minter.updatePeriod();

        // next cycle is always the next even divisor of the cycle length above current block timestamp.
        uint32 currentCycle = (block.timestamp.toUint32() / gaugeCycleLength) * gaugeCycleLength;
        uint32 lastCycle = gaugeCycle;

        // ensure new cycle has begun
        if (currentCycle <= lastCycle) revert CycleError();

        if (currentCycle > nextCycle) {
            nextCycle = currentCycle;
            paginationOffset = 0;
        }

        uint32 offset = paginationOffset;

        // important to only calculate the reward amount once to prevent each page from having a different reward amount
        if (offset == 0) {
            // queue the rewards stream and sanity check the tokens were received
            uint256 balanceBefore = rewardToken.balanceOf(address(this));
            uint256 newRewards = minter.getRewards();
            require(rewardToken.balanceOf(address(this)) - balanceBefore >= newRewards);
            require(newRewards <= type(uint112).max); // safe cast
            nextCycleQueuedRewards += uint112(newRewards); // in case a previous incomplete cycle had rewards, add on
        }

        uint112 queued = nextCycleQueuedRewards;

        uint256 remaining = gaugeToken.numGauges() - offset;

        // Important to do non-strict inequality to include the case where the numRewards is just enough to complete the cycle
        if (remaining <= numRewards) {
            numRewards = remaining;
            gaugeCycle = currentCycle;
            nextCycleQueuedRewards = 0;
            paginationOffset = 0;
            emit CycleStart(currentCycle, queued);
        } else {
            paginationOffset = offset + numRewards.toUint32();
        }

        // iterate over all gauges and update the rewards allocations
        address[] memory gauges = gaugeToken.gauges(offset, numRewards);

        _queueRewards(gauges, currentCycle, lastCycle, queued);
    }

    /*//////////////////////////////////////////////////////////////
                        FLYWHEEL CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Queues the rewards for the next cycle for each given gauge.
     * @param gauges array of gauges addresses to queue rewards for.
     * @param currentCycle timestamp representing the beginning of the new cycle.
     * @param lastCycle timestamp representing the end of the of the last cycle.
     * @param totalQueuedForCycle total number of rewards queued for the next cycle.
     */
    function _queueRewards(address[] memory gauges, uint32 currentCycle, uint32 lastCycle, uint256 totalQueuedForCycle)
        internal
    {
        uint256 size = gauges.length;

        if (size == 0) revert EmptyGaugesError();

        for (uint256 i = 0; i < size; i++) {
            ERC20 gauge = ERC20(gauges[i]);

            QueuedRewards memory queuedRewards = gaugeQueuedRewards[gauge];

            // Cycle queue already started
            require(queuedRewards.storedCycle < currentCycle);
            assert(queuedRewards.storedCycle == 0 || queuedRewards.storedCycle >= lastCycle);

            uint112 completedRewards = queuedRewards.storedCycle == lastCycle ? queuedRewards.cycleRewards : 0;
            uint256 nextRewards = gaugeToken.calculateGaugeAllocation(address(gauge), totalQueuedForCycle);
            require(nextRewards <= type(uint112).max); // safe cast

            gaugeQueuedRewards[gauge] = QueuedRewards({
                priorCycleRewards: queuedRewards.priorCycleRewards + completedRewards,
                cycleRewards: uint112(nextRewards),
                storedCycle: currentCycle
            });

            emit QueueRewards(address(gauge), currentCycle, nextRewards);
        }
    }

    /// @inheritdoc IFlywheelGaugeRewards
    function getAccruedRewards() external returns (uint256 accruedRewards) {
        /// @dev Update minter cycle and queue rewars if needed.
        minter.updatePeriod();

        QueuedRewards memory queuedRewards = gaugeQueuedRewards[ERC20(msg.sender)];

        uint32 cycle = gaugeCycle;
        bool incompleteCycle = queuedRewards.storedCycle > cycle;

        // no rewards
        if (queuedRewards.priorCycleRewards == 0 && (queuedRewards.cycleRewards == 0 || incompleteCycle)) {
            return 0;
        }

        // if stored cycle != 0 it must be >= the last queued cycle
        assert(queuedRewards.storedCycle >= cycle);

        // always accrue prior rewards
        accruedRewards = queuedRewards.priorCycleRewards;
        uint112 cycleRewardsNext = queuedRewards.cycleRewards;

        if (incompleteCycle) {
            // If current cycle queue incomplete, do nothing to current cycle rewards or accrued
        } else {
            accruedRewards += cycleRewardsNext;
            cycleRewardsNext = 0;
        }

        gaugeQueuedRewards[ERC20(msg.sender)] = QueuedRewards({
            priorCycleRewards: 0,
            cycleRewards: cycleRewardsNext,
            storedCycle: queuedRewards.storedCycle
        });

        if (accruedRewards > 0) rewardToken.safeTransfer(msg.sender, accruedRewards);
    }
}
