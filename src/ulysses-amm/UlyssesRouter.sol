// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {UlyssesPool} from "./UlyssesPool.sol";

import {IUlyssesRouter, UlyssesFactory} from "./interfaces/IUlyssesRouter.sol";

/// @title Ulysses Router - Handles routing of transactions in the Ulysses AMM
contract UlyssesRouter is IUlyssesRouter {
    using SafeTransferLib for address;

    /// @notice Mapping from pool id to Ulysses pool.
    mapping(uint256 => UlyssesPool) private pools;

    /// @inheritdoc IUlyssesRouter
    UlyssesFactory public ulyssesFactory;

    constructor(UlyssesFactory _ulyssesFactory) {
        ulyssesFactory = _ulyssesFactory;
    }

    /*//////////////////////////////////////////////////////////////
                        Internal LOGIC
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Returns the Ulysses pool for the given id.
     * @param id The id of the Ulysses pool.
     */
    function getUlyssesLP(uint256 id) private returns (UlyssesPool ulysses) {
        ulysses = pools[id];
        if (address(ulysses) == address(0)) {
            ulysses = ulyssesFactory.pools(id);

            if (address(ulysses) == address(0)) revert UnrecognizedUlyssesLP();

            pools[id] = ulysses;

            address(ulysses.asset()).safeApprove(address(ulysses), type(uint256).max);
        }
    }

    /*//////////////////////////////////////////////////////////////
                         LIQUIDITY LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IUlyssesRouter
    function addLiquidity(uint256 amount, uint256 minOutput, uint256 poolId) external returns (uint256) {
        UlyssesPool ulysses = getUlyssesLP(poolId);

        amount = ulysses.deposit(amount, msg.sender);

        if (amount < minOutput) revert OutputTooLow();
        return amount;
    }

    /// @inheritdoc IUlyssesRouter
    function removeLiquidity(uint256 amount, uint256 minOutput, uint256 poolId) external returns (uint256) {
        UlyssesPool ulysses = getUlyssesLP(poolId);

        amount = ulysses.redeem(amount, msg.sender, msg.sender);

        if (amount < minOutput) revert OutputTooLow();
        return amount;
    }

    /*//////////////////////////////////////////////////////////////
                            SWAP LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IUlyssesRouter
    function swap(uint256 amount, uint256 minOutput, Route[] calldata routes) external returns (uint256) {
        address(getUlyssesLP(routes[0].from).asset()).safeTransferFrom(msg.sender, address(this), amount);

        uint256 length = routes.length;

        for (uint256 i = 0; i < length;) {
            amount = getUlyssesLP(routes[i].from).swapIn(amount, routes[i].to);

            unchecked {
                ++i;
            }
        }

        if (amount < minOutput) revert OutputTooLow();

        unchecked {
            --length;
        }

        address(getUlyssesLP(routes[length].to).asset()).safeTransfer(msg.sender, amount);

        return amount;
    }
}
