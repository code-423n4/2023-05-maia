// SPDX-License-Identifier: MIT
// Rewards logic inspired by Uniswap V3 Contracts (Uniswap/v3-staker/contracts/libraries/NFTPositionInfo.sol)
pragma solidity ^0.8.0;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

// TODO: The INIT_CODE_HASH needs to be updated to the values that are live on the chain of it's deployment.
import {PoolAddress} from "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";

/// @title Encapsulates the logic for getting info about a NFT token ID
library NFTPositionInfo {
    /// @param factory The address of the Uniswap V3 Factory used in computing the pool address
    /// @param nonfungiblePositionManager The address of the nonfungible position manager to query
    /// @param tokenId The unique identifier of an Uniswap V3 LP token
    /// @return pool The address of the Uniswap V3 pool
    /// @return tickLower The lower tick of the Uniswap V3 position
    /// @return tickUpper The upper tick of the Uniswap V3 position
    /// @return liquidity The amount of liquidity staked
    function getPositionInfo(
        IUniswapV3Factory factory,
        INonfungiblePositionManager nonfungiblePositionManager,
        uint256 tokenId
    ) internal view returns (IUniswapV3Pool pool, int24 tickLower, int24 tickUpper, uint128 liquidity) {
        address token0;
        address token1;
        uint24 fee;
        /// @dev This line causes stack too deep when compiling with the optimizer turned off.
        (,, token0, token1, fee, tickLower, tickUpper, liquidity,,,,) = nonfungiblePositionManager.positions(tokenId);

        pool = IUniswapV3Pool(
            PoolAddress.computeAddress(
                address(factory), PoolAddress.PoolKey({token0: token0, token1: token1, fee: fee})
            )
        );
    }
}
