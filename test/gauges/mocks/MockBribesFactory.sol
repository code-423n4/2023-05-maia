// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "@gauges/factories/BribesFactory.sol";

contract MockBribesFactory is BribesFactory {

    constructor(
        BaseV2GaugeManager _gaugeManager,
        FlywheelBoosterGaugeWeight _flywheelGaugeWeightBooster,
        uint256 _rewardsCycleLength,
        address _owner
    ) BribesFactory(_gaugeManager, _flywheelGaugeWeightBooster, _rewardsCycleLength, _owner) {}

    // function getFlywheelGaugeWeightBooster() public returns (FlywheelBoosterGaugeWeight) {
    //     return flywheelGaugeWeightBooster;
    // }
}
