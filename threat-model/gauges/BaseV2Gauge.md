# BaseV2Gauge

- [constructor](#function-constructor)
- [newEpoch](#function-newepoch)
- [attachUser](#function-attachuser)
- [detachUser](#function-detachuser)
- [accrueBribes](#function-accruebribes)
- [addBribeFlywheel](#function-addbribeflywheel)
- [removeBribeFlywheel](#function-removebribeflywheel)


## Function: `constructor`

The contract is created over the `BaseV2GaugeFactory.createGauge()` function, which is available only for the owner of `BaseV2GaugeFactory`. This contract is actually part of the `UniswapV3Gauge` contract.

### Inputs

- `_flywheelGaugeRewards`:
  - **Control**: The address of `flywheelGaugeRewards` contract, which is passed by the deployer of `UniswapV3GaugeFactory` to the constructor.
  - **Authorization**: No checks.
  - **Impact**: The `accruedRewards` value will be received from `flywheelGaugeRewards.getAccruedRewards` and deposited to `UniswapV3Staker` as a reward for staking.
- `_strategy`:
  - **Control**: Full control.
  - **Authorization**: None.
  - **Impact**: The functions `attachUser` and `detachUser` can be called only by this address.
- `_owner`:
  - **Control**: The address of `BaseV2GaugeFactory`.
  - **Authorization**: Nonzero.
  - **Impact**: Only the owner can call `addBribeFlywheel` and `removeBribeFlywheel` functions.

### Function call analysis

- `BaseV2GaugeFactory(msg.sender).bHermesBoostToken()`
  - **What is controllable?**: Nothing.
  - **If return value controllable, how is it used and how can it go wrong?**: Returns the address of the `hermesGaugeBoost` contract, which manages info about the user's boost and allows the gauge to be attached to the user's boost. Due to the `msg.sender` trusting `BaseV2GaugeFactory`, the `bHermesBoostToken` is also trusted.
  - **What happens if it reverts, reenters, or does other unusual control flow?**: No problems.
- `_flywheelGaugeRewards.rewardToken()`
  - **What is controllable?**: Nothing.
  - **If return value controllable, how is it used and how can it go wrong?**: Returns the address of the `rewardToken` contract. This address will be called to assign full approval to the `_uniswapV3Staker` address, so it can manage all `rewardToken` tokens of these contracts. As the `_flywheelGaugeRewards` is a trusted contract, there are not any problems. Inside the `_flywheelGaugeRewards`, the `rewardToken` address is set by the deployer.
  - **What happens if it reverts, reenters, or does other unusual control flow?**: No problems.

## Function: `newEpoch`

This function is available for any caller and allows them to initialize a new epoch when the time has come. The caller only controls the timing of when the function will be called.

### Branches and code coverage

**Intended branches:**

- The epoch was updated.
  - [ ] Test coverage
- The reward was distributed to the `UniswapV3Staker` contract.
  - [ ] Test coverage

**Negative behavior:**

- The new epoch hasn't come.
  - [ ] Negative test?

### Function call analysis

- `flywheelGaugeRewards.getAccruedRewards()`
  - **What is controllable?**: Nothing.
  - **If return value controllable, how is it used and how can it go wrong?**: The caller does not control the return value. The return value is the amount of reward that will be distributed to the `UniswapV3Staker` contract.
  - **What happens if it reverts, reenters, or does other unusual control flow?**: The rewards are not accrued.
- `IUniswapV3Staker(uniswapV3Staker).createIncentiveFromGauge(amount)`
  - **What is controllable?**: Nothing.
  - **If return value controllable, how is it used and how can it go wrong?**: There is no return value here.
  - **What happens if it reverts, reenters, or does other unusual control flow?**: This call will revert if the gauge contract does not have the corresponding strategy contract inside the `uniswapV3Staker`. Actually, it will be the same `strategy` address that was added to this contract during deployment.

## Function: `attachUser`

Allows the strategy address to attach a new user to the `hermesGaugeBoost` contract.

### Branches and code coverage

**Intended branches:**

- New `user` was attached.
  - [ ] Test coverage

**Negative behavior:**

- The caller is not the strategy address.
  - [ ] Negative test?

### Inputs

- `user`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: Only the strategy can call this function.

### Function call analysis

- `hermesGaugeBoost.attach(user)`
  - **What is controllable?**: `user`.
  - **If return value controllable, how is it used and how can it go wrong?**: There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?**: It will revert if this gauge contract is not an active gauge inside the `hermesGaugeBoost` contract, or if the `user` is already attached.

## Function: `detachUser`

Allows the `strategy` address to detach the `user` from the `_userGauges` inside the `hermesGaugeBoost` contract.

### Branches and code coverage

**Intended branches:**

- The user was detached.
  - [ ] Test coverage

**Negative behavior:**

- The caller is not the `strategy` address.
  - [ ] Negative test?
- The `user` wasn't attached before.
  - [ ] Negative test?

### Inputs

- `user`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: Only `strategy` can call this function.

### Function call analysis

- `hermesGaugeBoost.detach(user)`
  - **What is controllable?**: `user`.
  - **If return value controllable, how is it used and how can it go wrong?**: There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?**: It cannot revert.

## Function: `accrueBribes`

Allows any caller to update the reward value inside the FlywheelCore contract. The reward value is based on the `boostedBalanceOf` of `user` [the `getUserGaugeWeight(user,strategy)` value].

### Branches and code coverage

**Intended branches:**

- The full reward value is calculated properly for `user` (check the `rewardsAccrued[user]` value inside all `bribeFlywheels` contracts).
  - [ ] Test coverage

**Negative behavior:**

- The `bhermes.getUserGaugeWeight` for `user` is zero.
  - [ ] Negative test?

### Inputs

- `user`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The user's address who can claim the reward.

### Function call analysis

- `_bribeFlywheels[i].accrue(ERC20(address(this)), user)`
  - **What is controllable?**: `user`.
  - **If return value controllable, how is it used and how can it go wrong?**: There is no return value here.
  - **What happens if it reverts, reenters, or does other unusual control flow?**: It can revert in case of calculation error, but there are no specific checks.

## Function: `addBribeFlywheel`

Allows the owner of the contract to add a trusted FlywheelCore contract. The owner of this contract is the BaseV2GaugeFactory contract.

### Branches and code coverage

**Intended branches:**

- `bribeFlywheel` is active.
  - [ ] Test coverage

**Negative behavior:**

- The `bribeFlywheel` address was already added.
  - [ ] Negative test?
- The caller is not the owner.
  - [ ] Negative test?
- The `bribeFlywheel` address was removed.
  - [ ] Negative test?

### Inputs

- `bribeFlywheel`:
  - **Control**: Only the owner can call this function.
  - **Authorization**: The function is called from the `BaseV2GaugeFactory:addBribeToGauge()` function, which can be called only by the owner of this factory contract or by the owner of the `bribesFactory` contract. The trusted `bribeFlywheel` address associated with the bribeToken created over the `BribesFactory` will be passed to the `addBribeFlywheel` function. The `bribeFlywheel` should already be added.
  - **Impact**: The `accrue` function from this contract will be triggered to accrue rewards for a user every time users call `incrementGauge` or `decrementGauge`.

### Function call analysis

- `bribeFlywheel.flywheelRewards()`:
  - **What is controllable?**: `bribeFlywheel`.
  - **If return value controllable, how is it used and how can it go wrong?**: No problem because the owner of the contract calls the trusted `bribeFlywheel` contract.
  - **What happens if it reverts, reenters, or does other unusual control flow?**: Returns the address of the contract that manages the reward transferring.
- `bribeFlywheel.rewardToken()`:
  - **What is controllable?**: `bribeFlywheel`.
  - **If return value controllable, how is it used and how can it go wrong?**: The return address is the reward token address.
  - **What happens if it reverts, reenters, or does other unusual control flow?**: No problem, just return the public address value.
- `FlywheelBribeRewards(flyWheelRewards).setRewardsDepot(multiRewardsDepot)`:
  - **What is controllable?**: `flyWheelRewards`.
  - **If return value controllable, how is it used and how can it go wrong?**: There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?**: This function associates the contract address with the `multiRewardsDepot` inside the `FlywheelBribeRewards` contract.
- `multiRewardsDepot.addAsset(flyWheelRewards, bribeFlywheel.rewardToken())`:
  - **What is controllable?**: `flyWheelRewards` and `bribeFlywheel.rewardToken()`.
  - **If return value controllable, how is it used and how can it go wrong?**: There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?**: The `flyWheelRewards` is a contract that will be able to get the full reward from the rewardToken. The function will revert if `flyWheelRewards` or `rewardToken` is already added.

## Function: `removeBribeFlywheel`

Allows the owner of the contract to remove the active FlywheelCore contract. This address will not be removed from `bribeFlywheels` and `added` lists, but it will be removed from `isActive`. The address cannot be re-added.

