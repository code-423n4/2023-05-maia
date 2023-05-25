// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "@talos/factories/BoostAggregatorFactory.sol";

contract MockBoostAggregatorFactory is BoostAggregatorFactory {

    constructor(
        UniswapV3Staker _uniswapV3Staker
    ) BoostAggregatorFactory(_uniswapV3Staker) {}
}
