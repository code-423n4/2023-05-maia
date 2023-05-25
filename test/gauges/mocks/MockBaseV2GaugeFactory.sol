// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "@gauges/factories/BaseV2GaugeFactory.sol";

contract MockBaseV2GaugeFactory is BaseV2GaugeFactory {
    constructor(
        BaseV2GaugeManager _gaugeManager,
        bHermesBoost _bHermesBoost,
        BribesFactory _bribesFactory,
        address _owner
    ) BaseV2GaugeFactory(_gaugeManager, _bHermesBoost, _bribesFactory, _owner) {}

    function newGauge(address strategy, bytes memory) internal pure override returns (BaseV2Gauge) {
        return BaseV2Gauge(strategy);
    }

    function afterCreateGauge(address strategy, bytes memory) internal override {}

    function changeActiveGauge(BaseV2Gauge gauge, bool state) external {
        activeGauges[gauge] = state;
    }
}
