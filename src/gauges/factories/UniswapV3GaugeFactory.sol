// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {bHermesBoost} from "@hermes/tokens/bHermesBoost.sol";

import {UniswapV3Gauge, BaseV2Gauge} from "@gauges/UniswapV3Gauge.sol";

import {FlywheelGaugeRewards} from "@rewards/rewards/FlywheelGaugeRewards.sol";

import {
    UniswapV3Staker,
    IUniswapV3Factory,
    INonfungiblePositionManager,
    IUniswapV3Pool
} from "@v3-staker/UniswapV3Staker.sol";

import {BribesFactory} from "./BribesFactory.sol";
import {BaseV2GaugeFactory} from "./BaseV2GaugeFactory.sol";
import {BaseV2GaugeManager} from "./BaseV2GaugeManager.sol";

import {IUniswapV3GaugeFactory} from "../interfaces/IUniswapV3GaugeFactory.sol";

/// @title Uniswap V3 Gauge Factory
contract UniswapV3GaugeFactory is BaseV2GaugeFactory, IUniswapV3GaugeFactory {
    /*//////////////////////////////////////////////////////////////
                         FACTORY STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IUniswapV3GaugeFactory
    UniswapV3Staker public immutable override uniswapV3Staker;

    /// @inheritdoc IUniswapV3GaugeFactory
    FlywheelGaugeRewards public immutable override flywheelGaugeRewards;

    /**
     * @notice Creates a new Uniswap V3 Gauge Factory
     * @param _gaugeManager Gauge Factory manager
     * @param _bHermesBoost bHermes Boost Token
     * @param _factory Uniswap V3 Factory
     * @param _nonfungiblePositionManager Uniswap V3 Nonfungible Position Manager
     * @param _flywheelGaugeRewards Flywheel Gauge Rewards
     * @param _bribesFactory Bribes Factory
     * @param _owner Owner of this contract
     */
    constructor(
        BaseV2GaugeManager _gaugeManager,
        bHermesBoost _bHermesBoost,
        IUniswapV3Factory _factory,
        INonfungiblePositionManager _nonfungiblePositionManager,
        FlywheelGaugeRewards _flywheelGaugeRewards,
        BribesFactory _bribesFactory,
        address _owner
    ) BaseV2GaugeFactory(_gaugeManager, _bHermesBoost, _bribesFactory, _owner) {
        flywheelGaugeRewards = _flywheelGaugeRewards;
        uniswapV3Staker = new UniswapV3Staker(
            _factory,
            _nonfungiblePositionManager,
            this,
            _bHermesBoost,
            52 weeks,
            address(_flywheelGaugeRewards.minter()),
            address(_flywheelGaugeRewards.rewardToken())
        );
    }

    /*//////////////////////////////////////////////////////////////
                         GAUGE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new Uniswap V3 Gauge
    function newGauge(address strategy, bytes memory data) internal override returns (BaseV2Gauge) {
        uint24 minimumWidth = abi.decode(data, (uint24));
        return new UniswapV3Gauge(
                flywheelGaugeRewards,
                address(uniswapV3Staker),
                strategy,
                minimumWidth,
                address(this)
            );
    }

    /// @notice Adds Gauge to UniswapV3Staker
    /// @dev Updates the UniswapV3 staker with bribe and minimum width information
    function afterCreateGauge(address strategy, bytes memory) internal override {
        uniswapV3Staker.updateGauges(IUniswapV3Pool(strategy));
    }

    /*//////////////////////////////////////////////////////////////
                         ADMIN LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IUniswapV3GaugeFactory
    function setMinimumWidth(address gauge, uint24 minimumWidth) external onlyOwner {
        if (!activeGauges[BaseV2Gauge(gauge)]) revert InvalidGauge();
        UniswapV3Gauge(gauge).setMinimumWidth(minimumWidth);
        uniswapV3Staker.updateGauges(IUniswapV3Pool(UniswapV3Gauge(gauge).strategy()));
    }
}
