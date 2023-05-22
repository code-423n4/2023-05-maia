// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {UniswapV3Staker} from "@v3-staker/UniswapV3Staker.sol";

import {BoostAggregator} from "../boost-aggregator/BoostAggregator.sol";

import {IBoostAggregatorFactory} from "../interfaces/IBoostAggregatorFactory.sol";

/// @title Boost Aggregator Factory
contract BoostAggregatorFactory is IBoostAggregatorFactory {
    /*//////////////////////////////////////////////////////////////
                    BOOST AGGREGATOR FACTORY STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBoostAggregatorFactory
    UniswapV3Staker public immutable uniswapV3Staker;

    /// @inheritdoc IBoostAggregatorFactory
    ERC20 public immutable hermes;

    /// @inheritdoc IBoostAggregatorFactory
    BoostAggregator[] public boostAggregators;

    /// @inheritdoc IBoostAggregatorFactory
    mapping(BoostAggregator => uint256) public boostAggregatorIds;

    /**
     * @notice Construct a new Boost Aggregator Factory contract.
     * @param _uniswapV3Staker Uniswap V3 Staker to use.
     */
    constructor(UniswapV3Staker _uniswapV3Staker) {
        uniswapV3Staker = _uniswapV3Staker;
        hermes = ERC20(_uniswapV3Staker.hermes());

        boostAggregators.push(BoostAggregator(address(0)));
    }

    /// @inheritdoc IBoostAggregatorFactory
    function getBoostAggregators() external view returns (BoostAggregator[] memory) {
        return boostAggregators;
    }

    /*//////////////////////////////////////////////////////////////
                            CREATE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBoostAggregatorFactory
    function createBoostAggregator(address owner) external {
        if (owner == address(0)) revert InvalidOwner();
        BoostAggregator boostAggregator = new BoostAggregator(uniswapV3Staker, hermes, owner);

        boostAggregatorIds[boostAggregator] = boostAggregators.length;
        boostAggregators.push(boostAggregator);
    }
}
