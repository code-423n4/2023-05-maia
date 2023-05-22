// SPDX-License-Identifier: MIT
// Rewards logic inspired by Tribe DAO Contracts (flywheel-v2/src/rewards/IFlywheelBooster.sol)
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {bHermesGauges} from "@hermes/tokens/bHermesGauges.sol";

import {IFlywheelBooster} from "../interfaces/IFlywheelBooster.sol";

/**
 * @title Balance Booster Module for Flywheel
 *  @notice Flywheel is a general framework for managing token incentives.
 *          It takes reward streams to various *strategies* such as staking LP tokens and divides them among *users* of those strategies.
 *
 *          The Booster module is an optional module for virtually boosting or otherwise transforming user balances.
 *          If a booster is not configured, the strategies ERC-20 balanceOf/totalSupply will be used instead.
 *
 *          Boosting logic can be associated with referrals, vote-escrow, or other strategies.
 *
 *          SECURITY NOTE: similar to how Core needs to be notified any time the strategy user composition changes, the booster would need to be notified of any conditions which change the boosted balances atomically.
 *          This prevents gaming of the reward calculation function by using manipulated balances when accruing.
 *
 *          NOTE: Gets total and user voting power allocated to each strategy.
 *
 * ⣿⡇⣿⣿⣿⠛⠁⣴⣿⡿⠿⠧⠹⠿⠘⣿⣿⣿⡇⢸⡻⣿⣿⣿⣿⣿⣿⣿
 * ⢹⡇⣿⣿⣿⠄⣞⣯⣷⣾⣿⣿⣧⡹⡆⡀⠉⢹⡌⠐⢿⣿⣿⣿⡞⣿⣿⣿
 * ⣾⡇⣿⣿⡇⣾⣿⣿⣿⣿⣿⣿⣿⣿⣄⢻⣦⡀⠁⢸⡌⠻⣿⣿⣿⡽⣿⣿
 * ⡇⣿⠹⣿⡇⡟⠛⣉⠁⠉⠉⠻⡿⣿⣿⣿⣿⣿⣦⣄⡉⠂⠈⠙⢿⣿⣝⣿
 * ⠤⢿⡄⠹⣧⣷⣸⡇⠄⠄⠲⢰⣌⣾⣿⣿⣿⣿⣿⣿⣶⣤⣤⡀⠄⠈⠻⢮
 * ⠄⢸⣧⠄⢘⢻⣿⡇⢀⣀⠄⣸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⡀⠄⢀
 * ⠄⠈⣿⡆⢸⣿⣿⣿⣬⣭⣴⣿⣿⣿⣿⣿⣿⣿⣯⠝⠛⠛⠙⢿⡿⠃⠄⢸
 * ⠄⠄⢿⣿⡀⣿⣿⣿⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣿⣿⣿⣿⡾⠁⢠⡇⢀
 * ⠄⠄⢸⣿⡇⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣏⣫⣻⡟⢀⠄⣿⣷⣾
 * ⠄⠄⢸⣿⡇⠄⠈⠙⠿⣿⣿⣿⣮⣿⣿⣿⣿⣿⣿⣿⣿⡿⢠⠊⢀⡇⣿⣿
 * ⠒⠤⠄⣿⡇⢀⡲⠄⠄⠈⠙⠻⢿⣿⣿⠿⠿⠟⠛⠋⠁⣰⠇⠄⢸⣿⣿⣿
 * ⠄⠄⠄⣿⡇⢬⡻⡇⡄⠄⠄⠄⡰⢖⠔⠉⠄⠄⠄⠄⣼⠏⠄⠄⢸⣿⣿⣿
 * ⠄⠄⠄⣿⡇⠄⠙⢌⢷⣆⡀⡾⡣⠃⠄⠄⠄⠄⠄⣼⡟⠄⠄⠄⠄⢿⣿⣿
 */
contract FlywheelBoosterGaugeWeight is IFlywheelBooster {
    /// @notice the bHermes gauge weight contract
    bHermesGauges private immutable bhermes;

    /**
     * @notice constructor
     * @param _bHermesGauges the bHermes gauge weight contract
     */
    constructor(bHermesGauges _bHermesGauges) {
        bhermes = _bHermesGauges;
    }

    /// @inheritdoc IFlywheelBooster
    /// @dev Total gauge weight allocated to the strategy
    function boostedTotalSupply(ERC20 strategy) external view returns (uint256) {
        return bhermes.getGaugeWeight(address(strategy));
    }

    /// @inheritdoc IFlywheelBooster
    /// @dev User's gauge weight allocated to the strategy
    function boostedBalanceOf(ERC20 strategy, address user) external view returns (uint256) {
        return bhermes.getUserGaugeWeight(user, address(strategy));
    }
}
