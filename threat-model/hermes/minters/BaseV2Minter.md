# BaseV2Minter

- [fallback()](#function-fallback)
- [getRewards()](#function-getrewards)
- [initialize(FlywheelGaugeRewards \_flywheelGaugeRewards)](#function-initializeflywheelgaugerewards-_flywheelgaugerewards)
- [setDaoShare(uint256 \_daoShare)](#function-setdaoshareuint256-_daoshare)
- [setDao(address \_dao)](#function-setdaoaddress-_dao)
- [setTailEmission(uint256 \_tail_emission)](#function-settailemissionuint256-_tail_emission)
- [updatePeriod()](#function-updateperiod)


## Function: `fallback()`

Triggers the `updatePeriod` method to update emission information.

### Branches and code coverage

**Intended branches**

- The fallback method triggers an update.
  - [x] Test coverage

## Function: `getRewards()`

Distributes the weekly emissions to the `flywheelGaugeRewards` contract.

### Preconditions

Only callable by the owner.

### Branches and code coverage

**Intended branches**

- The weekly emissions are transferred to `msg.sender` and reset to 0.
  - [x] Test coverage

**Negative behavior**

- The caller is not the `flywheelGaugeRewards`.
  - [x] Negative test?

### Function call analysis

- `underlying.safeTransfer(msg.sender, totalQueuedForCycle)`
  - **What is controllable?** N/A.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual control flow?** The tokens will not be transferred.

## Function: `initialize(FlywheelGaugeRewards \_flywheelGaugeRewards)`

Initialize the contract state, setting up the current active period and the rewards flywheel.

### Preconditions

Only callable by the initializer.

### Branches and code coverage

**Intended branches**

- The initializer is set to 0, the `flywheelGaugeRewards` is set, and the active period is set to the current week.
  - [x] Test coverage

**Negative behavior**

- The caller is not the initializer.
  - [x] Negative test?

### Inputs

- `_flywheelGaugeRewards`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: This will be where the rewards are sent.

## Function: `setDaoShare(uint256 \_daoShare)`

Sets the percentage share of emissions that is sent to the DAO.

### Preconditions

Only callable by the owner.

### Branches and code coverage

**Intended branches**

- The DAO share is set.
  - [x] Test coverage

**Negative behavior**

- The DAO share is too high.
  - [x] Negative test?
- The caller is not the owner.
  - [ ] Negative test?

### Inputs

- `_daoShare`:
  - **Control**: Must be less than or equal to 300 (30%).
  - **Authorization**: No checks.
  - **Impact**: This will be the percentage share of emissions that is sent to the DAO.

## Function: `setDao(address \_dao)`

Sets the DAO address for transferring a share of the weekly emissions.

### Preconditions

Only callable by the owner.

### Branches and code coverage

**Intended branches**

- The DAO address is set.
  - [x] Test coverage

**Negative behavior**

- The caller is not the owner.
  - [ ] Negative test?

### Inputs

- `_dao`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: This address will be sent a share of the weekly emissions.

## Function: `setTailEmission(uint256 \_tail_emission)`

Change the tail emissions used to calculate the weekly emissions.

### Preconditions

Only callable by the owner.

### Branches and code coverage

**Intended branches**

- Sets the new tail emission value.
  - [x] Test coverage

**Negative behavior**

- The tail emission value is too high.
  - [x] Negative test?
- The caller is not the owner.
  - [ ] Negative test?

### Inputs

- `_tail_emission`:
  - **Control**: Must be less than or equal to 100 (10%).
  - **Authorization**: No checks.
  - **Impact**: This will be the new tail emission value used for calculating the weekly emissions.

## Function: `updatePeriod()`

Updates critical information surrounding emissions, such as the weekly emissions, and mints the tokens for the previous week's rewards. Update period can only be called once per cycle (one week).

The weekly emissions are accumulated to the following week if getRewards is not called in time.

### Branches and code coverage

**Intended branches**

- The current block timestamp is not during the active period, so nothing happens.
  - [ ] Test coverage
- The current block timestamp is during the active period, so the period is updated to the next week, the emission tokens are calculated and minted, and the growth is distributed to the vault.
  - [x] Test coverage
- The current block timestamp is during the active period, so the period is updated to the next week, the emission tokens are calculated, no tokens are minted as the minter already has enough, and the growth is distributed to the vault.
  - [ ] Test coverage

### Function call analysis

- `underlying.balanceOf(address(this))`:
  - **What is controllable?** N/A.
  - **If return value controllable, how is it used and how can it go wrong?** The return value could be controlled by sending tokens to the contract, but that would mean that fewer tokens are minted this period.
  - **What happens if it reverts, reenters, or does other unusual control flow?** The period will not be updated.
- `HERMES(underlying).mint(address(this), _required - _balanceOf)`:
  - **What is controllable?** N/A.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual control flow?** The period will not be updated.
- `underlying.safeTransfer(address(vault), _growth)`:
  - **What is controllable?** N/A.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual control flow?** The period will not be updated.
- `underlying.safeTransfer(dao, share)`:
  - **What is controllable?** N/A.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual control flow?** The period will not be updated.
- `flywheelGaugeRewards.queueRewardsForCycle()`:
  - **What is controllable?** N/A.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual control flow?** The function will successfully complete, and any errors are caught and ignored.

