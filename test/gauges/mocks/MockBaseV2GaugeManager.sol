// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "@gauges/factories/BaseV2GaugeManager.sol";

contract MockBaseV2GaugeManager is BaseV2GaugeManager {
    constructor(bHermes _bHermes, address _owner, address _admin) BaseV2GaugeManager(_bHermes, _owner, _admin) {}

    // function newGauge(address strategy, bytes memory) internal pure override returns (BaseV2Gauge) {
    //     return BaseV2Gauge(strategy);
    // }

    // function afterCreateGauge(address strategy, bytes memory) internal override {}

    function changeActiveGaugeFactory(BaseV2GaugeFactory gaugeFactory, bool state) external {
        activeGaugeFactories[gaugeFactory] = state;
    }
}
