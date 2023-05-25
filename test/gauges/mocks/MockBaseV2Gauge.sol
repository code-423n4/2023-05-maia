// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "@gauges/BaseV2Gauge.sol";

contract MockBaseV2Gauge is BaseV2Gauge {
    /// @notice rewards amount per strategy
    mapping(ERC20 => uint256) public rewardsAmount;

    uint256 public rewards;

    constructor(FlywheelGaugeRewards _flywheelGaugeRewards, address _strategy, address _owner)
        BaseV2Gauge(_flywheelGaugeRewards, _strategy, _owner)
    {
        _initializeOwner(_owner);
    }

    function distribute(uint256 amount) internal override {}
}
