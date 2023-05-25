# BaseV2GaugeFactory

- [addBribeToGauge(BaseV2Gauge gauge, address bribeToken)](#function-addbribetogaugebasev2gauge-gauge-address-bribetoken)
- [createGauge(address strategy, byte[] data)](#function-creategaugeaddress-strategy-byte-data)
- [newEpoch()](#function-newepoch)
- [newEpoch(uint256 start, uint256 end)](#function-newepochuint256-start-uint256-end)
- [removeBribeFromGauge(BaseV2Gauge gauge, address bribeToken)](#function-removebribefromgaugebasev2gauge-gauge-address-bribetoken)
- [removeGauge(BaseV2Gauge gauge)](#function-removegaugebasev2gauge-gauge)


## Function: `addBribeToGauge(BaseV2Gauge gauge, address bribeToken)`

Adds a new bribe to the gauge and adds the gauge to the bribeflywheel.

### Preconditions

The caller must be the owner or the bribe’s factory owner.

### Branches and code coverage

**Intended branches**

- An existing bribeflywheel is added to the gauge.
  - [ ] Test coverage

**Negative behavior**

- The bribeflywheel does not exist.
  - [ ] Negative test?
- The caller is not the owner or owner of the bribe factory.
  - [ ] Negative test?

### Inputs

- `gauge`
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: This address will have `addBribeFlywheel` called on it to add the bribeflywheel.
- `bribeToken`
  - **Control**: There must already be a bribeflywheel in the bribes factory for this token.
  - **Authorization**: No checks.
  - **Impact**: Used to determine which bribeflywheel to use.

### Function call analysis

- `bribesFactory.flywheelTokens(bribeToken)`:
  - **What is controllable?** The `bribeToken` is fully controllable.
  - **If return value controllable, how is it used and how can it go wrong?** There must already be a `flywheel` created or the result will be 0.
  - **What happens if it reverts, reenters, or does other unusual controlflow?** `gauge.addBribeFlywheel` will be called with 0, which will fail later on when `bribeFlywheel.flywheelRewards()` is called.
- `gauge.addBribeFlywheel(flywheelToken)`:
  - **What is controllable?** `gauge` is fully controllable.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual controlflow?** The bribe will not be added.
- `bribesFactory.addGaugetoFlywheel(address(gauge), bribeToken)`:
  - **What is controllable?** `gauge` and `bribeToken` are fully controllable.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual controlflow?** The bribe will not be added.

## Function: `createGauge(address strategy, byte[] data)`

Creates a new gauge for the given strategy.

### Preconditions

Only callable by the owner.

### Branches and code coverage

**Intended branches**

- A new gauge is created from the strategy and added to the active gauges.
  - [x] Test coverage

**Negative behavior**

- The caller is not the owner.
  - [ ] Negative test?
- The strategy already exists.
  - [ ] Negative test?

### Inputs

- `strategy`:
  - **Control**: The strategy must not already exist.
  - **Authorization**: No checks.
  - **Impact**: The strategy address will be passed to the implementing contract to create a new gauge.
- `data`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The data will be passed to the implementing contract to create a new gauge.

### Function call analysis

- `gaugeManager.addGauge(address(gauge))`:
  - **What is controllable?** `gauge` is fully controllable.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual controlflow?** The gauge will not be created.

## Function: `newEpoch()`

Triggers a new epoch on all active gauges.

### Branches and code coverage

**Intended branches**

- Each active gauge has its `newEpoch` function called.
  - [ ] Test coverage

**Negative behavior**

- Checked.
  - [ ] Negative test?
- Unchecked.
  - [ ] Negative test?

### Function call analysis

- `_gauges[i].newEpoch()`
  - **What is controllable?** N/A.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual controlflow?**
    If any of the gauges revert, then the whole function reverts.

## Function: `newEpoch(uint256 start, uint256 end)`

Same as `BaseV2GaugeFactory.newEpoch` but allows pagination of the gauges.

## Function: `removeBribeFromGauge(BaseV2Gauge gauge, address bribeToken)`

Removes a given bribe from a gauge.

### Preconditions

The caller must be the owner or the bribes factory owner.

### Branches and code coverage

**Intended branches**

- The gauge has the bribeflywheel removed.
  - [ ] Test coverage

**Negative behavior**

- There is no bribeflywheel for the token.
  - [ ] Negative test?
- The caller is not the owner or owner of the bribe factory.
  - [ ] Negative test?

### Inputs

- `gauge`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The gauge will have `removeBribeFlywheel` called on it with the flywheel address.
- `bribeToken`:
  - **Control**: There must be a bribeflywheel in the bribe's factory for the token.
  - **Authorization**: No checks.
  - **Impact**: Determines which bribeflywheel will be removed.

### Function call analysis

- `bribesFactory.flywheelTokens(bribeToken)`:
  - **What is controllable?** The `bribeToken` is fully controllable.
  - **If return value controllable, how is it used and how can it go wrong?** If there is no bribeflywheel, then 0 will be returned.
  - **What happens if it reverts, reenters, or does other unusual controlflow?** The bribe will not be removed from the gauge.

## Function: `removeGauge(BaseV2Gauge gauge)`

Removes a gauge and its strategy from the factory.

### Preconditions

Only callable by the owner.

### Branches and code coverage

**Intended branches**

- The gauge and its strategy are removed.
  - [ ] Test coverage

**Negative behavior**

- The caller is not the owner.
  - [ ] Negative test?

### Inputs

- `gauge`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The gauge and its strategy will be removed.

### Function call analysis

- `gauge.strategy()`:
  - **What is controllable?** gauge is fully controllable.
  - **If return value controllable, how is it used and how can it go wrong?** If the gauge is not an active gauge but shares a strategy with one, then it could potentially remove the `strategyGauges` - the active one, allowing two gauges to share the same strategy.
  - **What happens if it reverts, reenters, or does other unusual controlflow?** The gauge will not be removed.
- `gaugeManager.removeGauge(address(gauge))`:
  - **What is controllable?** gauge is fully controllable.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual controlflow?** The gauge will not be removed.

