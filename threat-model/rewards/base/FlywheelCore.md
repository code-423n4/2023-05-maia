# FlywheelCore

- [accrue(ERC20 strategy, address user)](#function-accrueerc20-strategy-address-user)
- [accrue(ERC20 strategy, address user, address secondUser)](#function-accrueerc20-strategy-address-user-address-seconduser)
- [accrueStrategy(ERC20 strategy, uint256 state)](#function-accruestrategyerc20-strategy-uint256-state)
- [accrueUser(ERC20 strategy, address user, uint256 index)](#function-accrueusererc20-strategy-address-user-uint256-index)
- [claimRewards(address user)](#function-claimrewardsaddress-user)
- [addStrategyForRewards(ERC20 strategy)](#function-addstrategyforrewardserc20-strategy)
- [setFlywheelRewards(address newFlywheelRewards)](#function-setflywheelrewardsaddress-newflywheelrewards)
- [setBooster(IFlywheelBooster newBooster)](#function-setboosteriflywheelbooster-newbooster)


The `FlywheelCoreStrategy` and the `FlywheelCoreInstant` contracts are inherited from this contract.

## Function: `accrue(ERC20 strategy, address user)`

The function calls the `accrueStrategy` with the current `strategyIndex` of `strategyAddress`. The `trustedStrategyAddress` should be initialized inside the `strategyIndexList` by the owner of the contract; otherwise, this function will return zero. Also, see the descriptions of the `accrueStrategy` and `accrueUser` functions.

## Function: `accrue(ERC20 strategy, address user, address secondUser)`

This is the same as `accrue(ERC20 strategy, address user)` but allows calling `accrueUser` two times. Also, see the descriptions of the `accrueStrategy` and `accrueUser` functions.

## Function: `accrueStrategy(ERC20 strategy, uint256 state)`

The function allows to calculate rewards per token.

### Branches and code coverage

**Intended branches:**

- The `strategyIndex[strategy]` was calculated properly.
  - [ ] Test coverage

**Negative behavior:**

- `strategyRewardsAccrue` is zero.
  - [ ] Negative test?
- `strategyIndex` does not contain the `strategy`.
  - [ ] Negative test?

### Inputs

- `strategy`:
  - **Control**: Full control.
  - **Authorization**: If `strategyIndex` of `strategy` is zero, the function `accrue`, which calls this function, will return 0.
  - **Impact**: The address of `strategy` is associated with the `rewardsDepot` contract inside the `FlywheelBribeRewards` contract.
- `state`:
  - **Control**: No control.
  - **Authorization**: None.
  - **Impact**: This value is the previous `rewardsIndex` value.

### Function call analysis

- `flywheelBooster.boostedTotalSupply(strategy)`:

  - **What is controllable?** `strategy`.
  - **If return value controllable, how is it used and how can it go wrong?** In the case of an untrusted `flywheelBooster` contract, this can affect the reward value.
  - **What happens if it reverts, reenters, or does other unusual control flow?** No problems.

- `strategy.totalSupply()`:

  - **What is controllable?** `strategy`.
  - **If return value controllable, how is it used and how can it go wrong?** In the case of an untrusted `strategy` contract, this can affect the reward value.
  - **What happens if it reverts, reenters, or does other unusual control flow?** No problems.

- `IFlywheelAcummulatedRewards(flywheelRewards).getAccruedRewards(strategy)`:
  - **What is controllable?** `strategy`.
  - **If return value controllable, how is it used and how can it go wrong?** Not controllable.
  - **What happens if it reverts, reenters, or does other unusual control flow?** No problems.

## Function: `accrueUser(ERC20 strategy, address user, uint256 index)`

The function allows calculating user rewards.

### Branches and code coverage

**Intended branches:**

- The `rewardsAccrued[user]` was calculated properly.
  - [ ] Test coverage

**Negative behavior:**

- `strategy.balanceOf(user)` is zero.
  - [ ] Negative test?
- `flywheelBooster.boostedBalanceOf(strategy, user)` is zero.
  - [ ] Negative test?

### Inputs

- `strategy`:
  - **Control**: Full control.
  - **Authorization**: If `strategyIndex` of `strategy` is zero, the function `accrue`, which calls this function, will return 0.
  - **Impact**: The address of `strategy` is associated with the `rewardsDepot` contract inside the `FlywheelBribeRewards` contract. This contract can also be called to receive the balance of `user`.
- `user`:
  - **Control**: Full control.
  - **Authorization**: `flywheelBooster.boostedBalanceOf(strategy, user)` or `strategy.balanceOf(user)` should be nonzero.
  - **Impact**: The address of the user who can claim the reward.
- `index`:
  - **Control**: No control.
  - **Authorization**: None.
  - **Impact**: The reward per token.

### Function call analysis

- `flywheelBooster.boostedBalanceOf(strategy, user)`:

  - **What is controllable?** `strategy` and `user`.
  - **If return value controllable, how is it used and how can it go wrong?** In the case of an untrusted `flywheelBooster` contract, this can affect how much reward a user receives.
  - **What happens if it reverts, reenters, or does other unusual control flow?** No problems.

- `strategy.balanceOf(user)`:
  - **What is controllable?** `strategy` and `user`.
  - **If return value controllable, how is it used and how can it go wrong?** In the case of an untrusted `strategy` contract, the wrong return value will affect the reward value (e.g., the user can steal the full reward).
  - **What happens if it reverts, reenters, or does other unusual control flow?** No problems.

## Function: `claimRewards(address user)`

Allows any caller who owns rewards inside this contract to transfer them to their address.

### Branches and code coverage

**Intended branches:**

- The `rewardToken` balance of `user` increased by `reward` value.
  - [x] Test coverage

**Negative behavior:**

- `rewardsAccrued[user]` == 0.
  - [ ] Negative test?

### Inputs

- `user`:
  - **Control**: Full control.
  - **Authorization**: `rewardsAccrued[user]` != 0.
  - **Impact**: The owner of the rewards.

### Function call analysis

- `rewardToken.safeTransferFrom(address(flywheelRewards), user, accrued)`
  - **What is controllable?** `user`.
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?** No problem.

## Function: `addStrategyForRewards(ERC20 strategy)`

Allows the contract owner to add new trusted strategy contract address.

## Function: `setFlywheelRewards(address newFlywheelRewards)`

Allows the contract owner to update the flywheelRewards contract address, which
stores unclaimed rewards. The full unclaimed reward balance will be transferred to
the new `flywheelRewards` address.

## Function: `setBooster(IFlywheelBooster newBooster)`

Allows the owner of the function to update the `flywheelBooster` address.

