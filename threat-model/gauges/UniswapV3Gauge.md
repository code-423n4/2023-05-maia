# UniswapV3Gauge

- [constructor](#function-constructor)
- [setMinimumWidth](#function-setminimumwidth)


## Function: `constructor`

The `newUniswapV3Gauge` is created in the `newGauge` function inside the `UniswapV3GaugeFactory` contract. The `UniswapV3GaugeFactory` is the owner of this contract. Also, initialize the `BaseV2Gauge` contract and approve for transferring the max amount of `rewardToken` to the `_uniswapV3Staker` address.

### Inputs

- `_flywheelGaugeRewards`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: Used in the `BaseV2Gauge` constructor.
- `_owner`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: Used in the `BaseV2Gauge` constructor.
- `_minimumWidth`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: During staking, the difference between `tickUpper` and `tickLower` cannot be less than this value.
- `_uniswapV3Pool`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: Used in the `BaseV2Gauge` constructor.
- `_uniswapV3Staker`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The address that will have approval from the contract to control tokens.

### Function call analysis

- `rewardToken.safeApprove(_uniswapV3Staker, type(uint256).max)`:
  - **What is controllable?** `_uniswapV3Staker`.
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value here.
  - **What happens if it reverts, reenters, or does other unusual control flow?** No problems.

## Function: `setMinimumWidth`

Allows the owner of the contract to set the minimum difference between `tickUpper` and `tickLower`.

