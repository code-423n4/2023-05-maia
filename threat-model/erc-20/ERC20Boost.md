# ERC20Boost

- [attach](#function-attach)
- [detach](#function-detach)
- [updateUserBoost](#function-updateuserboost)
- [decrementGaugeBoost](#function-decrementgaugeboost)
- [decrementGaugeAllBoost](#function-decrementgaugeallboost)
- [decrementAllGaugesBoost](#function-decrementallgaugesboost)
- [decrementGaugesBoostIndexed](#function-decrementgaugesboostindexed)
- [decrementAllGaugesAllBoost](#function-decrementallgaugesallboost)
- [addGauge](#function-addgauge)
- [removeGauge](#function-removegauge)
- [replaceGauge](#function-replacegauge)
- [transferFrom](#function-transferfrom)
- [transfer](#function-transfer)


The gauges are created inside the `BaseV2GaugeFactory` contract's over `createGauge` function: the `newGauge()` function is called, and after that, `gaugeManager.addGauge`. The `createGauge` function is available only for the owner of the `BaseV2GaugeFactory` contract.

## Function: `attach`

External function. Allows to attach user’s boost to a gauge.

### Preconditions

The `msg.sender` should be `gauge` and not `deprecatedGauge`. Only the owner of the contract can add trusted gauge addresses.

### Branches and code coverage

**Intended branches:**

- The caller is `gauge` and is not `deprecatedGauge`.
  - [x] Test coverage

**Negative behavior:**

- The caller is already attached to `user`.
  - [x] Negative test?
- The caller is `deprecatedGauge`.
  - [x] Negative test?
- The caller is not `gauge`.
  - [x] Negative test?

### Inputs

- `msg.sender` :
  - **Control**: N/A.
  - **Authorization**: `_gauges` should contain the `msg.sender` address and `_deprecatedGauges` should not contain this.
  - **Impact**: Only the gauge address can attach the user’s boost.
- `user`:
  - **Control**: Full control.
  - **Authorization**: `msg.sender` should not be already attached to the user’s boost.
  - **Impact**: The current user balance will be used during reward calculations during staking.

## Function: `detach`

Allows to detach the user’s boost from a gauge. There is no check that `_userGauges[user]` contains `msg.sender` address.

### Branches and code coverage

**Intended branches:**

- Check that `getUserGaugeBoost[user]` does not contain `msg.sender` after detach.
  - [ ] Test coverage
- Check that `_userGauges[user]` does not contain `msg.sender` after detach.
  - [ ] Test coverage
- `msg.sender` successfully detached.
  - [x] Test coverage

**Negative behavior:**

- `msg.sender` is not attached.
  - [ ] Negative test?

### Inputs

- `user`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: `msg.sender` address will be deleted from `_userGauges` and `getUserGaugeBoost`.

## Function: `updateUserBoost`

Allows any caller to update the `getUserBoost` to the max from all `userGaugeBoost` values for this user. There is no check that `_userGauges` contains the user address.

### Branches and code coverage

**Intended branches:**

- The `getUserBoost[user]` is maximum after call.
  - [ ] Test coverage

**Negative behavior:**

- `_userGauges` does not contain the user address.
  - [ ] Negative test?

### Inputs

- `user`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: `getUserBoost` value for user will be updated to the max balance of the user. The `getUserBoost[user]` value is locked funds, which the user cannot transfer.

## Function: `decrementGaugeBoost`

Allows the user to decrement the gauge boost. If `getUserGaugeBoost[msg.sender][gauge]` is deleted, there is a need to remove the gauge address from `_userGauges[msg.sender]`. This function should be called by the user.

### Branches and code coverage

**Intended branches:**

- `userGaugeBoost` value is decremented by `boost` value.
  - [x] Test coverage

**Negative behavior:**

- User is not attached to the gauge.
  - [ ] Negative test?

### Inputs

- `boost`:
  - **Control**: Full control.
  - **Authorization**: If the current `userGaugeBoost` value is more than the `boost` value, the `userGaugeBoost` will be deleted.
  - **Impact**: The current user boost for the corresponding gauge will be decreased by this value. After that, the user can call `updateUserBoost` to update the global `getUserBoost[user]` value and increase the `freeGaugeBoost` value.
- `gauge`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: User can decrement the boost value only for the attached gauge.

## Function: `decrementGaugeAllBoost`

Allows the user to remove full boost value from the attached gauge.

### Branches and code coverage

**Intended branches:**

- After the call, the `getUserGaugeBoost[msg.sender]` does not contain the gauge.
  - [x] Test coverage
- After the call, the `_userGauges[msg.sender]` does not contain the gauge.
  - [ ] Test coverage

**Negative behavior:**

- The user is not attached to the gauge.
  - [ ] Negative test?

### Inputs

- `gauge`:
  - **Control**: Full control.
  - **Authorization**: User can remove only the attached `gauge` address.
  - **Impact**: The user will not have a boost for the corresponding `gauge` address.

## Function: `decrementAllGaugesBoost`

This is the same as the `decrementGaugeBoost()` function, but it allows removing an equal amount of boost from all user gauges.

## Function: `decrementGaugesBoostIndexed`

This is the same as the `decrementGaugeBoost()` function, but it allows removing an equal amount of boost from indexed user gauges.

## Function: `decrementAllGaugesAllBoost`

This allows removing the total amount of boost from all user gauges.

## Function: `addGauge`

The function can be called only by the contract owner. Allows the owner of the contract to add the new `gauge` address. The `gauge` must be deprecated if it has already been added.

### Branches and code coverage

**Intended branches:**

- The `gauge` is successfully added and removed from `_deprecatedGauges`.
  - [x] Test coverage
- `gauge` is deprecated and already added.
  - [ ] Negative test?

**Negative behavior:**

- `gauge` is already added.
  - [x] Negative test?
- `gauge` is not deprecated and already added.
  - [x] Negative test?
- `msg.sender` is not an owner of the contract.
  - [x] Negative test?

### Inputs

- `gauge`:
  - **Control**: Full control.
  - **Authorization**: The `gauge` is new and deprecated.
  - **Impact**: The trusted `gauge` contract, which can attach boost to arbitrary `user` addresses.

## Function: `removeGauge`

The function can be called only by the contract owner. Allows the owner of the contract to add the `gauge` address to the `_deprecatedGauges`. The `gauge` must not be already deprecated.

### Branches and code coverage

**Intended branches:**

- The `gauge` became deprecated.
  - [x] Test coverage

**Negative behavior:**

- The `gauge` is deprecated.
  - [ ] Negative test?
- `msg.sender` is not an owner of the contract.
  - [x] Negative test?

### Inputs

- `gauge`:
  - **Control**: Full control.
  - **Authorization**: Must not be previously deprecated.
  - **Impact**: This `gauge` contract cannot attach boost to user contracts, but the owner can move it to active gauges.

## Function: `replaceGauge`

The function can be called only by the contract owner. The function calls the `removeGauge` function for the `oldGauge` address, and it becomes deprecated, and the `addGauge` function for the `newGauge` address, and it becomes an active gauge.

### Branches and code coverage

**Intended branches:**

- After the call, the `newGauge` will be removed from deprecated if it was deprecated.
  - [ ] Test coverage
- After the call, the `oldGauge` becomes deprecated.
  - [x] Test coverage

**Negative behavior:**

- The `oldGauge` is already deprecated.
  - [ ] Negative test?
- The `newGauge` is not deprecated and already added.
  - [ ] Negative test?

### Inputs

- `newGauge`:
  - **Control**: Full control.
  - **Authorization**: Must be `previouslyDeprecated`, and `_gauges` contain this address.
  - **Impact**: The address of the gauge, which will be able to attach to user’s boost.
- `oldGauge`:
  - **Control**: Full control.
  - **Authorization**: Must not be `previouslyDeprecated`.
  - **Impact**: The gauge address, which becomes deprecated.

## Function: `transferFrom`

Calls the ERC20 `transferFrom` function. But before the transfer, there is a check that the amount cannot be more than `freeGaugeBoost` - the difference between the `from` balance and `userGaugeBoost` amount.

## Function: `transfer`

Calls the ERC20 `transfer` function. But before the transfer, there is a check that the amount cannot be more than `freeGaugeBoost` - the difference between the `msg.sender` balance and `userGaugeBoost` amount.

