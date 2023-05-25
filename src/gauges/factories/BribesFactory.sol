// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {BaseV2Gauge} from "@gauges/BaseV2Gauge.sol";

import {FlywheelBoosterGaugeWeight} from "@rewards/booster/FlywheelBoosterGaugeWeight.sol";
import {FlywheelBribeRewards} from "@rewards/rewards/FlywheelBribeRewards.sol";
import {FlywheelCore} from "@rewards/FlywheelCoreStrategy.sol";

import {BaseV2GaugeFactory, BaseV2GaugeManager} from "./BaseV2GaugeManager.sol";
import {IBribesFactory} from "../interfaces/IBribesFactory.sol";

/// @title Gauge Bribes Factory
contract BribesFactory is Ownable, IBribesFactory {
    /*///////////////////////////////////////////////////////////////
                        BRIBES FACTORY STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBribesFactory
    uint256 public immutable rewardsCycleLength;

    FlywheelBoosterGaugeWeight private immutable flywheelGaugeWeightBooster;

    /// @inheritdoc IBribesFactory
    FlywheelCore[] public bribeFlywheels;

    /// @inheritdoc IBribesFactory
    mapping(FlywheelCore => uint256) public bribeFlywheelIds;

    /// @inheritdoc IBribesFactory
    mapping(FlywheelCore => bool) public activeBribeFlywheels;

    /// @inheritdoc IBribesFactory
    mapping(address => FlywheelCore) public flywheelTokens;

    /// @inheritdoc IBribesFactory
    BaseV2GaugeManager public immutable gaugeManager;

    /**
     * @notice Creates a new bribes factory
     * @param _gaugeManager Gauge Factory manager
     * @param _flywheelGaugeWeightBooster Flywheel Gauge Weight Booster
     * @param _rewardsCycleLength Rewards Cycle Length
     * @param _owner Owner of this contract
     */
    constructor(
        BaseV2GaugeManager _gaugeManager,
        FlywheelBoosterGaugeWeight _flywheelGaugeWeightBooster,
        uint256 _rewardsCycleLength,
        address _owner
    ) {
        _initializeOwner(_owner);
        gaugeManager = _gaugeManager;
        flywheelGaugeWeightBooster = _flywheelGaugeWeightBooster;
        rewardsCycleLength = _rewardsCycleLength;
    }

    /// @inheritdoc IBribesFactory
    function getBribeFlywheels() external view returns (FlywheelCore[] memory) {
        return bribeFlywheels;
    }

    /*//////////////////////////////////////////////////////////////
                        CREATE BRIBE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBribesFactory
    function addGaugetoFlywheel(address gauge, address bribeToken) external onlyGaugeFactory {
        if (address(flywheelTokens[bribeToken]) == address(0)) createBribeFlywheel(bribeToken);

        flywheelTokens[bribeToken].addStrategyForRewards(ERC20(gauge));
    }

    /// @inheritdoc IBribesFactory
    function createBribeFlywheel(address bribeToken) public {
        if (address(flywheelTokens[bribeToken]) != address(0)) revert BribeFlywheelAlreadyExists();

        FlywheelCore flywheel = new FlywheelCore(
            bribeToken,
            FlywheelBribeRewards(address(0)),
            flywheelGaugeWeightBooster,
            address(this)
        );

        flywheelTokens[bribeToken] = flywheel;

        uint256 id = bribeFlywheels.length;
        bribeFlywheels.push(flywheel);
        bribeFlywheelIds[flywheel] = id;
        activeBribeFlywheels[flywheel] = true;

        flywheel.setFlywheelRewards(address(new FlywheelBribeRewards(flywheel, rewardsCycleLength)));

        emit BribeFlywheelCreated(bribeToken, flywheel);
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyGaugeFactory() {
        if (!gaugeManager.activeGaugeFactories(BaseV2GaugeFactory(msg.sender))) {
            revert Unauthorized();
        }
        _;
    }
}
