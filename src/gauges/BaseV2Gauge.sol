// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {bHermesBoost} from "@hermes/tokens/bHermesBoost.sol";

import {MultiRewardsDepot} from "@rewards/depots/MultiRewardsDepot.sol";
import {FlywheelBribeRewards} from "@rewards/rewards/FlywheelBribeRewards.sol";
import {FlywheelCore} from "@rewards/FlywheelCoreStrategy.sol";
import {FlywheelGaugeRewards} from "@rewards/rewards/FlywheelGaugeRewards.sol";

import {BaseV2GaugeFactory} from "./factories/BaseV2GaugeFactory.sol";

import {IBaseV2Gauge} from "./interfaces/IBaseV2Gauge.sol";

/// @title Base V2 Gauge - Base contract for handling liquidity provider incentives and voter's bribes.
abstract contract BaseV2Gauge is Ownable, IBaseV2Gauge {
    /*///////////////////////////////////////////////////////////////
                            GAUGE STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBaseV2Gauge
    address public immutable override rewardToken;

    /// @notice token to boost gauge rewards
    bHermesBoost public immutable hermesGaugeBoost;

    /// @inheritdoc IBaseV2Gauge
    FlywheelGaugeRewards public immutable override flywheelGaugeRewards;

    /// @inheritdoc IBaseV2Gauge
    mapping(FlywheelCore => bool) public override isActive;

    /// @inheritdoc IBaseV2Gauge
    mapping(FlywheelCore => bool) public override added;

    /// @inheritdoc IBaseV2Gauge
    address public override strategy;

    /// @inheritdoc IBaseV2Gauge
    MultiRewardsDepot public override multiRewardsDepot;

    /// @inheritdoc IBaseV2Gauge
    uint256 public override epoch;

    /// @notice Bribes flywheels array to accrue bribes from.
    FlywheelCore[] private bribeFlywheels;

    /// @notice 1 week in seconds.
    uint256 internal constant WEEK = 1 weeks;

    /**
     * @notice Constructs the BaseV2Gauge contract.
     * @param _flywheelGaugeRewards The FlywheelGaugeRewards contract.
     * @param _strategy The strategy address.
     * @param _owner The owner address.
     */
    constructor(FlywheelGaugeRewards _flywheelGaugeRewards, address _strategy, address _owner) {
        _initializeOwner(_owner);
        flywheelGaugeRewards = _flywheelGaugeRewards;
        rewardToken = _flywheelGaugeRewards.rewardToken();
        hermesGaugeBoost = BaseV2GaugeFactory(msg.sender).bHermesBoostToken();
        strategy = _strategy;

        epoch = (block.timestamp / WEEK) * WEEK;

        multiRewardsDepot = new MultiRewardsDepot(address(this));
    }

    /// @inheritdoc IBaseV2Gauge
    function getBribeFlywheels() external view returns (FlywheelCore[] memory) {
        return bribeFlywheels;
    }

    /*///////////////////////////////////////////////////////////////
                        GAUGE ACTIONS    
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBaseV2Gauge
    function newEpoch() external {
        uint256 _newEpoch = (block.timestamp / WEEK) * WEEK;

        if (epoch < _newEpoch) {
            epoch = _newEpoch;

            uint256 accruedRewards = flywheelGaugeRewards.getAccruedRewards();

            distribute(accruedRewards);

            emit Distribute(accruedRewards, _newEpoch);
        }
    }

    /// @notice Distributes weekly emissions to the strategy.
    function distribute(uint256 amount) internal virtual;

    /// @inheritdoc IBaseV2Gauge
    function attachUser(address user) external onlyStrategy {
        hermesGaugeBoost.attach(user);
    }

    /// @inheritdoc IBaseV2Gauge
    function detachUser(address user) external onlyStrategy {
        hermesGaugeBoost.detach(user);
    }

    /// @inheritdoc IBaseV2Gauge
    function accrueBribes(address user) external {
        FlywheelCore[] storage _bribeFlywheels = bribeFlywheels;
        uint256 length = _bribeFlywheels.length;
        for (uint256 i = 0; i < length;) {
            if (isActive[_bribeFlywheels[i]]) _bribeFlywheels[i].accrue(ERC20(address(this)), user);

            unchecked {
                i++;
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                            ADMIN ACTIONS    
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBaseV2Gauge
    function addBribeFlywheel(FlywheelCore bribeFlywheel) external onlyOwner {
        /// @dev Can't add existing flywheel (active or not)
        if (added[bribeFlywheel]) revert FlywheelAlreadyAdded();

        address flyWheelRewards = address(bribeFlywheel.flywheelRewards());
        FlywheelBribeRewards(flyWheelRewards).setRewardsDepot(multiRewardsDepot);

        multiRewardsDepot.addAsset(flyWheelRewards, bribeFlywheel.rewardToken());
        bribeFlywheels.push(bribeFlywheel);
        isActive[bribeFlywheel] = true;
        added[bribeFlywheel] = true;

        emit AddedBribeFlywheel(bribeFlywheel);
    }

    /// @inheritdoc IBaseV2Gauge
    function removeBribeFlywheel(FlywheelCore bribeFlywheel) external onlyOwner {
        /// @dev Can only remove active flywheels
        if (!isActive[bribeFlywheel]) revert FlywheelNotActive();

        /// @dev This is permanent; can't be re-added
        delete isActive[bribeFlywheel];

        emit RemoveBribeFlywheel(bribeFlywheel);
    }

    /// @notice Only the strategy can attach and detach users.
    modifier onlyStrategy() virtual {
        if (msg.sender != strategy) revert StrategyError();
        _;
    }
}
