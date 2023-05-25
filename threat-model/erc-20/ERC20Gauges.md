# ERC20Gauges

- [incrementGauge](#function-incrementgauge)
- [incrementGauges](#function-incrementgauges)
- [decrementGauge](#function-decrementgauge)
- [decrementGauges](#function-decrementgauges)
- [addGauge](#function-addgauge)
- [removeGauge](#function-removegauge)
- [setMaxGauges](#function-setmaxgauges)
- [setContractExceedMaxGauges](#function-setcontractexceedmaxgauges)
- [replaceGauge](#function-replacegauge)
- [transfer](#function-transfer)
- [transferFrom](#function-transferfrom)


## Function: `incrementGauge`

Allows the caller to increment the gauge weight. The number of user's gauges cannot be more than the `maxGauges` amount, except when `canContractExceedMaxGauges` contains the user address. The user cannot increment if the weight value is more than the user's owned votes.

### Branches and code coverage

**Intended branches:**

- `getUserGaugeWeight` increased by `weight`.
  - [ ] Test coverage
- `_getGaugeWeight` was updated properly.
  - [ ] Test coverage
- Check that `userGauges` contains the new `gauge`.
  - [ ] Test coverage
- `getUserWeight[user]` increased by `weight`.
  - [ ] Test coverage
- `_totalWeight` increased by `weight`.
  - [ ] Test coverage

**Negative behavior:**

- `weight` value is more than the user's token balance.
  - [ ] Negative test?
- The `gauge` is untrusted.
  - [ ] Negative test?
- The `gauge` is deprecated.
  - [ ] Negative test?

### Inputs

- `weight`:
  - **Control**: Full control.
  - **Authorization**: `_incrementUserAndGlobalWeights` checks that the `weight` cannot be more than the current user's votes amount.
  - **Impact**: The caller should not be able to set the `weight` value more than the number of tokens they own because the reward depends on this value.
- `gauge`:
  - **Control**: Full control.
  - **Authorization**: There is a check that the `gauge` is not deprecated inside the `_incrementGaugeWeight` function.
  - **Impact**: The gauge should be a trusted contract.

### Function call analysis

- `IBaseV2Gauge(gauge).accrueBribes(user)`:
  - **What is controllable?** `gauge`.
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value.
  - **What happens if it reverts, reenters, or does other unusual controlflow?** The caller controls the `gauge` address, so reentrancy is possible, but only before the weight changes.

## Function: `incrementGauges`

Allows the caller to increment weights for multiple gauges.

**Intended branches:**

- `_totalWeight` increased by the sum of `weights`.
  - [ ] Test coverage

**Negative behavior:**

- The sum of `weights` is more than what the user owns.
  - [ ] Negative test?
- Deprecated `gauge` addresses.
  - [ ] Negative test?
- Untrusted `gauge` addresses inside `gaugeList`.
  - [ ] Negative test?

**Inputs:**

- `weights`:
  - **Control**: Full control.
  - **Authorization**: The sum of weights cannot be more than the user's votes amount.
  - **Impact**: The caller should not be able to set the weight value more than the number of tokens they own because the reward depends on this value.
- `gaugeList`:
  - **Control**: Full control.
  - **Authorization**: `_deprecatedGauge` must not contain the gauge address.
  - **Impact**: The array of contract addresses is fully controlled by the user. In each loop step, the function `accrueBribes` will be called to accrue bribes for the given user.

**Function call analysis:**

- `IBaseV2Gauge(gauge).accrueBribes(user)`:
  - **What is controllable?** `gauge`.
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?** Due to the gauge being an arbitrary contract, and weight checks happening at the end of the call and after weight increasing, on the second step, the caller will control their weight amount and be able to steal funds from the contract.

## Function: `decrementGauge`

Allows the caller to decrement gauge weight.

**Intended branches:**

- `getUserGaugeWeight` decreased by `weight`.
  - [ ] Test coverage
- `_getGaugeWeight` was updated properly.
  - [ ] Test coverage
- Check that `_userGauges` do not contain `gauge` if the full weight was decremented.
  - [ ] Test coverage
- `getUserWeight[user]` decreased by `weight`.
  - [ ] Test coverage
- `_totalWeight` decreased by `weight`.
  - [ ] Test coverage

**Negative behavior:**

- The gauge is untrusted.
  - [ ] Negative test?
- The gauge is deprecated.
  - [ ] Negative test?

**Inputs:**

- `weight`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The user can decrease the weight by any amount, but not more than the current weight.
- `gauge`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The gauge should be a trusted contract.

**Function call analysis:**

- `IBaseV2Gauge(gauge).accrueBribes(user)`:
  - **What is controllable?** `gauge`.
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?** The caller controls the gauge address, but it should only be a trusted address. The call can run out of gas if there are too many elements in `bribeFlywheels`.

## Function: `decrementGauges`

Allows the caller to decrement weights for a bunch of gauges.

**Intended branches:**

- `_totalWeight` decreased by the sum of `weight`.
  - [ ] Test coverage

**Negative behavior:**

- Deprecated gauge addresses.
  - [ ] Negative test?
- Untrusted gauge addresses inside `gaugeList`.
  - [ ] Negative test?

**Inputs:**

- `weight`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The user can decrease the weight by any amount, but not more than the current weight.
- `gauge`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The gauge should be a trusted contract.

**Function call analysis:**

- `IBaseV2Gauge(gauge).accrueBribes(user)`:
  - **What is controllable?** `gauge`.
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?** Reentrancy is possible here, but the caller can only decrease the current weight of the gauge.

## Function: `addGauge`

Allows the owner of the contract to add trusted gauge contract addresses to the active gauges list. If a gauge has already been added, it must be deprecated. The owner of the contract is `msg.sender`.

**Intended branches:**

- New gauge added properly.
  - [ ] Test coverage
- Deprecated gauge was removed from `deprecated`.
  - [ ] Test coverage
- `_totalWeight` was updated by `_getGaugeWeight` value.
  - [ ] Test coverage

**Negative behavior:**

- Caller is not an owner.
  - [ ] Negative test?
- `gauge` is not deprecated and already added.
  - [ ] Negative test?

**Inputs:**

- `gauge`:
  - **Control**: Full control.
  - **Authorization**: If the `gauge` has already been added, it should be in `_deprecatedGauges`.
  - **Impact**: The gauge should be a trusted contract.

## Function: `removeGauge`

Allows the owner of the contract to remove trusted gauge contract addresses from the `_deprecatedGauges` list. The gauge must be deprecated if it has already been added. The owner of the contract is `msg.sender`.

**Intended branches:**

- Gauge is deprecated after the call.
  - [ ] Test coverage
- `_totalWeight` was decreased by `_getGaugeWeight` value.
  - [ ] Test coverage

**Negative behavior:**

- Caller is not an owner.
  - [ ] Negative test?
- `gauge` is deprecated.
  - [ ] Negative test?
- `gauge` is not active.
  - [ ] Negative test?

**Inputs:**

- `gauge`:
  - **Control**: Full control.
  - **Authorization**: The `gauge` is not in `_deprecatedGauges`.
  - **Impact**: The gauge should be an active contract. Additionally, if the gauge was attached to the `_totalWeight`, it will no longer be taken into account for the weight calculations.

## Function: `setMaxGauges`

Allows owner of the contract to change the `maxGauges` value. This does not affect the
current number of gauges, but it will affect the addition of new ones.

## Function: `setContractExceedMaxGauges`

Allows the owner of the contract to update the `canContractExceedMaxGauges` for `account`
address. The `account` should be the contract address.

## Function: `replaceGauge`

The function can be called only by the contract owner. The function calls the
`_removeGauge` function for the `oldGauge` address, and it becomes deprecated, and the
`_addGauge` function for the `newGauge` address, and it becomes an active gauge.

## Function: `transfer`

Allows transferring tokens from `msg.sender` to the `to` address. Before the transfer, the required number of tokens must be released from the attached gauges. The `transfer` function from `ERC20MultiVotes` will also be called to free up votes, so after the call, it is necessary to check that the votes have been decremented properly.

**Intended branches:**

- `_totalWeight` decreases properly (if gauge is in `_deprecatedGauges`, it should not be decreased by this weight).
  - [ ] Test coverage
- `amount` is equal to the full user balance (all gauges should be updated and all user variables become zero).
  - [ ] Test coverage

**Negative behavior:**

- The `msg.sender` does not have any tokens.
  - [ ] Negative test?

**Inputs:**

- `to`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The recipient of the tokens.
- `amount`:
  - **Control**: Full control.
  - **Authorization**: If the caller does not have enough tokens, the transaction will revert inside the `ERC20` transfer function.
  - **Impact**: The amount of tokens to transfer to the recipient.

### Function call analysis

- `IBaseV2Gauge(gauge).accrueBribes(user)`;
  - **What is controllable?** `gauge`.
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?**
    The gauge address is controlled by the caller, and there is no check that the gauge is trusted inside the `incrementGauge` function. This means the user can increase the weight for an arbitrary gauge contract, and these arbitrary contracts will be called inside this function, allowing for reentrancy attacks.

## Function: `transferFrom`

Allows transferring tokens from `from` user address by `msg.sender` who has an approval. Before the transfer, the required number of tokens must be released from the attached gauges. The `transferFrom` function from `ERC20MultiVotes` will also be called to free up votes, so after the call, it is necessary to check that the votes have been decremented properly.

**Intended branches:**

- `_totalWeight` decreases properly (if gauge is in `_deprecatedGauges`, it shouldn't be decreased by its weight).
  - [ ] Test coverage
- `amount` is equal to the full user balance (all his gauges should be updated, and all user variables become zero).
  - [ ] Test coverage

**Negative behavior:**

- The `msg.sender` doesn't have an approval.
  - [ ] Negative test?

**Inputs:**

- `from`:
  - **Control**: Full control.
  - **Authorization**: There is a check that `msg.sender` has approval from `from` address inside the ERC20 `transferFrom`.
  - **Impact**: The address that owns the tokens.
- `to`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The recipient of the tokens.
- `amount`:
  - **Control**: Full control.
  - **Authorization**: If the caller doesn't have enough tokens, the transaction will revert inside the ERC20 `transfer` function.
  - **Impact**: The amount of tokens to transfer to the recipient.

### Function call analysis

- `IBaseV2Gauge(gauge).accrueBribes(user)`;
  - **What is controllable?** `gauge`
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?**
    The gauge address is controlled by the caller, and there is no check that the gauge is trusted inside the `incrementGauge` function. This means the user can increase the weight for an arbitrary gauge contract, and these arbitrary contracts will be called inside this function, allowing for reentrancy attacks.

