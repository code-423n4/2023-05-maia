# BribesFactory

- [addGaugetoFlywheel(address gauge, address bribeToken)](#function-addgaugetoflywheeladdress-gauge-address-bribetoken)
- [createBribeFlywheel(address bribeToken)](#function-createbribeflywheeladdress-bribetoken)


## Function: `addGaugetoFlywheel(address gauge, address bribeToken)`

Adds a new strategy to an existing bribe flywheel, creating a new bribe flywheel if one does not exist.

### Branches and code coverage

**Intended branches**

- A gauge is added to an existing bribe flywheel.
  - [ ] Test coverage
- A new flywheel is created and the gauge is added to it.
  - [ ] Test coverage

**Negative behavior**

- The caller is not a whitelisted Gauge Factory.
  - [ ] Negative test?

### Inputs

- `gauge`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: This will be added to the flywheel as a strategy for rewards.
- `bribeToken`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: This determines which flywheel is used or creates a new flywheel with this token.

### Function call analysis

- `flywheelTokens[bribeToken].addStrategyForRewards(ERC20(gauge))`:
  - **What is controllable?** `bribeToken` and `gauge` are fully controllable.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual control flow?** The gauge will not be added.

## Function: `createBribeFlywheel(address bribeToken)`

Creates a new flywheel for the given bribe token address.

This function is missing the `onlyGaugeFactory` modifier, see finding 3.1.

### Branches and code coverage

**Intended branches**

- A new flywheel is created and added to the active list.
  - [ ] Test coverage

**Negative behavior**

- There is already a bribe flywheel for the token.
  - [ ] Negative test?

### Inputs

- `bribeToken`:
  - **Control**: There cannot already be a flywheel for this token.
  - **Authorization**: No checks.
  - **Impact**: A new bribe flywheel is created.

