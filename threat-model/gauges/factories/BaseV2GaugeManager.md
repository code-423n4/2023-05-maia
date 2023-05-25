# BaseV2GaugeManager

- [addGauge](#function-addgauge)
- [removeGauge](#function-removegauge)
- [changebHermesGaugeOwner](#function-changebhermesgaugeowner)
- [addGaugeFactory()](#function-addgaugefactory)
- [removeGaugeFactory](#function-removegaugefactory)


This is the contract owner of `bHermesGauges` and `bHermesBoost`.

## Function: `addGauge`

Allows only `activeGaugeFactories` to add trusted gauge contract.

### Branches and code coverage

**Intended branches:**

- The gauge address is set properly inside `bHermesGauges` and `bHermesBoost`.
  - [ ] Test coverage

**Negative behavior:**

- The caller is not `activeGaugeFactories`.
  - [ ] Negative test?

### Inputs

- `msg.sender` :
  - **Control**: N/A.
  - **Authorization**: `onlyActiveGaugeFactory` - only owner of contract can set `activeGaugeFactories`.
  - **Impact**: Any caller should not be able to add an arbitrary gauge address.
- `gauge`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: gauge address should be trusted.

### Function call analysis

- `bHermesGaugeBoost.addGauge(gauge)`:
  - **What is controllable?** `gauge`.
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?** gauge address should be trusted.
- `bHermesGaugeWeight.addGauge(gauge)`:
  - **What is controllable?** `gauge`.
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?** gauge address should be trusted.

## Function: `removeGauge`

Allows only `activeGaugeFactories` to set trusted gauge contract as deprecated.

## Function: `changebHermesGaugeOwner`

Allows admin of contract to change owner address of `bHermesGauges` and `bHermesBoost` contracts.

### Branches and code coverage

**Intended branches:**

- `newOwner` is set properly.
  - [ ] Test coverage

**Negative behavior:**

- The old owner cannot control the contract.
  - [ ] Negative test?
- Caller is not an admin.
  - [ ] Negative test?

### Inputs

- `newOwner`:
  - **Control**: Full control.
  - **Authorization**: There is a check that the address is nonzero inside the `transferOwnership` function.
  - **Impact**: The new owner will be able to control the contract, so the address should be trusted.

### Function call analysis

- `bHermesGaugeBoost.transferOwnership(newOwner)`
  - **What is controllable?**: `newOwner`.
  - **If return value controllable, how is it used and how can it go wrong?**: There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?**: No problems.
- `bHermesGaugeWeight.transferOwnership(newOwner)`
  - **What is controllable?**: `newOwner`.
  - **If return value controllable, how is it used and how can it go wrong?**: There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?**: No problems.

## Function: `addGaugeFactory()`

**Intended behavior**

Allows the owner of the contract to add a trusted factory contract address.

### Branches and code coverage

**Intended branches:**

- Check that `gaugeFactory` is `activeGaugeFactories` after the call.
  - [ ] Test coverage

**Negative behavior:**

- Caller is not an owner.
  - [ ] Negative test?

### Inputs

- `gaugeFactory`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: This contract will be able to set and remove the trusted gauge contracts.

## Function: `removeGaugeFactory`

Allows owner of contract to remove trusted factory contract address.

