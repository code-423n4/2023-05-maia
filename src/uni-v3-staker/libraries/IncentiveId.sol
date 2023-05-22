// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// Rewards logic inspired by Uniswap V3 Contracts (Uniswap/v3-staker/contracts/libraries/IncentiveId.sol)

import {IUniswapV3Staker} from "@v3-staker/interfaces/IUniswapV3Staker.sol";

/**
 * @title Incentive ID hash library
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice This library is responsible for computing the incentive identifier.
 */
library IncentiveId {
    /// @dev Calculate the key for a staking incentive
    /// @param key The components used to compute the incentive identifier
    /// @return incentiveId The identifier for the incentive
    function compute(IUniswapV3Staker.IncentiveKey memory key) internal pure returns (bytes32 incentiveId) {
        return keccak256(abi.encode(key));
    }
}
