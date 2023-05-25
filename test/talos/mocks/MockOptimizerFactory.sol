// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "@talos/factories/OptimizerFactory.sol";

contract MockOptimizerFactory is OptimizerFactory {

    constructor() OptimizerFactory() {}
}
