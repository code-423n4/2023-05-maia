// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {RewardMath} from "@v3-staker/libraries/RewardMath.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@uniswap/v3-core/contracts/libraries/FullMath.sol";

import {console2} from "forge-std/console2.sol";

// Contract to test the RewardMath library
contract RewardMathTest is DSTestPlus {
    function testComputeRewardAmountNoBoostExists() public {
        uint256 totalRewardUnclaimed = 1000 ether;
        uint160 totalSecondsClaimedX128 = 0;
        uint160 startTime = 1625000000;
        uint160 endTime = 1625000000 + 7 days;
        uint128 boostAmount = 0;
        uint128 boostTotalSupply = 0;
        uint160 secondsPerLiquidityInsideInitialX128 = 0;
        uint128 liquidity = 1000 ether;
        uint160 stakedDuration = 7 days;
        uint256 currentTime = endTime;

        uint160 secondsInsideX128 = RewardMath.computeBoostedSecondsInsideX128(
            stakedDuration,
            liquidity,
            boostAmount,
            boostTotalSupply,
            secondsPerLiquidityInsideInitialX128,
            (stakedDuration << 128) / liquidity
        );

        uint256 reward = RewardMath.computeBoostedRewardAmount(
            totalRewardUnclaimed, totalSecondsClaimedX128, startTime, endTime, secondsInsideX128, currentTime
        );

        assertEq(reward, 399999999999999999999);
        assertEq(secondsInsideX128, 82321110205513433081059200000000000000000000);
    }

    function testComputeRewardAmountNoBoost() public {
        uint256 totalRewardUnclaimed = 1000 ether;
        uint160 totalSecondsClaimedX128 = 0;
        uint160 startTime = 1625000000;
        uint160 endTime = 1625000000 + 7 days;
        uint128 boostAmount = 0;
        uint128 boostTotalSupply = 1000 ether;
        uint160 secondsPerLiquidityInsideInitialX128 = 0;
        uint128 liquidity = 1000 ether;
        uint160 stakedDuration = 7 days;
        uint256 currentTime = endTime;

        uint160 secondsInsideX128 = RewardMath.computeBoostedSecondsInsideX128(
            stakedDuration,
            liquidity,
            boostAmount,
            boostTotalSupply,
            secondsPerLiquidityInsideInitialX128,
            (stakedDuration << 128) / liquidity
        );

        uint256 reward = RewardMath.computeBoostedRewardAmount(
            totalRewardUnclaimed, totalSecondsClaimedX128, startTime, endTime, secondsInsideX128, currentTime
        );

        assertEq(reward, 399999999999999999999);
        assertEq(secondsInsideX128, 82321110205513433081059200000000000000000000);
    }

    function testComputeRewardAmountMaxBoost() public {
        uint256 totalRewardUnclaimed = 1000 ether;
        uint160 totalSecondsClaimedX128 = 0;
        uint160 startTime = 1625000000;
        uint160 endTime = 1625000000 + 7 days;
        uint160 stakedDuration = 7 days;
        uint128 liquidity = 1000 ether;
        uint128 boostAmount = 1000 ether;
        uint128 boostTotalSupply = 1000 ether;
        uint160 secondsPerLiquidityInsideInitialX128 = 0;
        uint160 inputSecondsInsideX128 = stakedDuration << 128;
        uint256 currentTime = endTime;

        uint160 secondsInsideX128 = RewardMath.computeBoostedSecondsInsideX128(
            stakedDuration,
            liquidity,
            boostAmount,
            boostTotalSupply,
            secondsPerLiquidityInsideInitialX128,
            inputSecondsInsideX128 / liquidity
        );

        uint256 reward = RewardMath.computeBoostedRewardAmount(
            totalRewardUnclaimed, totalSecondsClaimedX128, startTime, endTime, secondsInsideX128, currentTime
        );

        assertEq(reward, 999999999999999999999);
        assertEq(secondsInsideX128, 205802775513783582702648000000000000000000000);
    }

    function testComputeRewardAmountHalfBoost() public {
        uint256 totalRewardUnclaimed = 1000 ether;
        uint160 totalSecondsClaimedX128 = 0;
        uint160 startTime = 1625000000;
        uint160 endTime = 1625000000 + 7 days;
        uint160 stakedDuration = 7 days;
        uint128 liquidity = 1000 ether;
        uint128 boostAmount = 500 ether;
        uint128 boostTotalSupply = 1000 ether;
        uint160 secondsPerLiquidityInsideInitialX128 = 0;
        uint160 inputSecondsInsideX128 = stakedDuration << 128;
        uint256 currentTime = endTime;

        uint160 secondsInsideX128 = RewardMath.computeBoostedSecondsInsideX128(
            stakedDuration,
            liquidity,
            boostAmount,
            boostTotalSupply,
            secondsPerLiquidityInsideInitialX128,
            inputSecondsInsideX128 / liquidity
        );

        uint256 reward = RewardMath.computeBoostedRewardAmount(
            totalRewardUnclaimed, totalSecondsClaimedX128, startTime, endTime, secondsInsideX128, currentTime
        );

        assertEq(reward, 699999999999999999999);
        assertEq(secondsInsideX128, 144061942859648507891853888772420024286576640);
    }

    function testFuzzComputeRewardAmount(uint128 boostAmount) public {
        uint256 stakedDuration = 7 days;
        uint128 liquidity = 1000 ether;
        uint128 boostTotalSupply = 1000 ether;
        uint160 secondsPerLiquidityInsideInitialX128 = 0;
        uint256 inputSecondsInsideX128 = stakedDuration << 128;

        boostAmount %= boostTotalSupply;

        uint160 secondsInsideX128 = RewardMath.computeBoostedSecondsInsideX128(
            stakedDuration,
            liquidity,
            boostAmount,
            boostTotalSupply,
            secondsPerLiquidityInsideInitialX128,
            uint160(inputSecondsInsideX128 / liquidity)
        );

        uint256 reward;
        uint256 totalRewardUnclaimed = 1000 ether;
        uint160 startTime = 1625000000;
        uint160 endTime = 1625000000 + 7 days;

        if (boostTotalSupply > 0) {
            // calculate boosted seconds insisde, 40% of original value + 60% of ((staked duration * boost amount) / boost total supply)
            uint160 boostedSecondsInsideX128 = uint160(
                ((inputSecondsInsideX128 * 4) / 10)
                    + ((((stakedDuration << 128) * boostAmount) / boostTotalSupply) * 6) / 10
            );

            // calculate boosted boosted seconds inside, can't be larger than original reward amount
            if (boostedSecondsInsideX128 < inputSecondsInsideX128) inputSecondsInsideX128 = boostedSecondsInsideX128;
        }

        uint256 totalSecondsUnclaimedX128 = ((endTime - startTime) << 128);

        uint256 boostedReward = FullMath.mulDiv(totalRewardUnclaimed, inputSecondsInsideX128, totalSecondsUnclaimedX128);

        uint160 totalSecondsClaimedX128 = 0;
        uint256 currentTime = endTime;

        reward = RewardMath.computeBoostedRewardAmount(
            totalRewardUnclaimed, totalSecondsClaimedX128, startTime, endTime, secondsInsideX128, currentTime
        );
        assertApproxEq(reward, boostedReward, 1);
        assertApproxEq(secondsInsideX128, inputSecondsInsideX128, liquidity);
    }

    function testFuzzComputeRewardAmount(uint128 boostAmount, uint256 inputSecondsInsideX128) public {
        uint256 stakedDuration = 7 days;
        uint128 liquidity = 1000 ether;
        uint128 boostTotalSupply = 1000 ether;
        uint160 secondsPerLiquidityInsideInitialX128 = 0;

        inputSecondsInsideX128 %= (stakedDuration << 128);
        inputSecondsInsideX128++;

        boostAmount %= boostTotalSupply;

        uint160 secondsInsideX128 = RewardMath.computeBoostedSecondsInsideX128(
            stakedDuration,
            liquidity,
            boostAmount,
            boostTotalSupply,
            secondsPerLiquidityInsideInitialX128,
            uint160(inputSecondsInsideX128 / liquidity)
        );

        uint256 totalRewardUnclaimed = 1000 ether;
        uint160 totalSecondsClaimedX128 = 0;
        uint160 startTime = 1625000000;
        uint160 endTime = 1625000000 + 7 days;
        uint256 currentTime = endTime;

        if (boostTotalSupply > 0) {
            // calculate boosted seconds insisde, 40% of original value + 60% of ((staked duration * boost amount) / boost total supply)
            uint160 boostedSecondsInsideX128 = uint160(
                ((inputSecondsInsideX128 * 4) / 10)
                    + ((((stakedDuration << 128) * boostAmount) / boostTotalSupply) * 6) / 10
            );

            // calculate boosted boosted seconds inside, can't be larger than original reward amount
            if (boostedSecondsInsideX128 < inputSecondsInsideX128) inputSecondsInsideX128 = boostedSecondsInsideX128;
        }

        uint256 totalSecondsUnclaimedX128 = ((endTime - startTime) << 128);

        uint256 boostedReward = FullMath.mulDiv(totalRewardUnclaimed, inputSecondsInsideX128, totalSecondsUnclaimedX128);

        uint256 reward = RewardMath.computeBoostedRewardAmount(
            totalRewardUnclaimed, totalSecondsClaimedX128, startTime, endTime, secondsInsideX128, currentTime
        );
        assertApproxEq(reward, boostedReward, 1);
        assertApproxEq(secondsInsideX128, inputSecondsInsideX128, liquidity);
    }

    function testFuzzComputeRewardAmount(uint128 boostAmount, uint256 inputSecondsInsideX128, uint256 stakedDuration)
        public
    {
        uint128 liquidity = 1000 ether;
        uint128 boostTotalSupply = 1000 ether;
        uint160 secondsPerLiquidityInsideInitialX128 = 0;

        stakedDuration %= 7 days;
        stakedDuration++;

        inputSecondsInsideX128 %= (stakedDuration << 128);
        inputSecondsInsideX128++;

        boostAmount %= boostTotalSupply;

        uint160 secondsInsideX128 = RewardMath.computeBoostedSecondsInsideX128(
            stakedDuration,
            liquidity,
            boostAmount,
            boostTotalSupply,
            secondsPerLiquidityInsideInitialX128,
            uint160(inputSecondsInsideX128 / liquidity)
        );

        uint256 totalRewardUnclaimed = 1000 ether;
        uint160 totalSecondsClaimedX128 = 0;
        uint160 startTime = 1625000000;
        uint160 endTime = 1625000000 + 7 days;
        uint256 currentTime = endTime;

        if (boostTotalSupply > 0) {
            // calculate boosted seconds insisde, 40% of original value + 60% of ((staked duration * boost amount) / boost total supply)
            uint160 boostedSecondsInsideX128 = uint160(
                ((inputSecondsInsideX128 * 4) / 10)
                    + ((((stakedDuration << 128) * boostAmount) / boostTotalSupply) * 6) / 10
            );

            // calculate boosted boosted seconds inside, can't be larger than original reward amount
            if (boostedSecondsInsideX128 < inputSecondsInsideX128) inputSecondsInsideX128 = boostedSecondsInsideX128;
        }

        uint256 totalSecondsUnclaimedX128 = ((endTime - startTime) << 128);

        uint256 boostedReward = FullMath.mulDiv(totalRewardUnclaimed, inputSecondsInsideX128, totalSecondsUnclaimedX128);

        uint256 reward = RewardMath.computeBoostedRewardAmount(
            totalRewardUnclaimed, totalSecondsClaimedX128, startTime, endTime, secondsInsideX128, currentTime
        );
        assertApproxEq(reward, boostedReward, 1);
        assertApproxEq(secondsInsideX128, inputSecondsInsideX128, liquidity);
    }
}
