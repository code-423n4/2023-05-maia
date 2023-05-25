# TalosOptimizer

- [setMaxTotalSupply(uint256 \_maxTotalSupply)](#function-setmaxtotalsupplyuint256-_maxtotalsupply)
- [setMaxTwapDeviation(int24 \_maxTwapDeviation)](#function-setmaxtwapdeviationint24-_maxtwapdeviation)
- [setPriceImpact(uint24 \_priceImpactPercentage)](#function-setpriceimpactuint24-_priceimpactpercentage)
- [setTickRange(int24 \_tickRangeMultiplier)](#function-settickrangeint24-_tickrangemultiplier)
- [setTwapDuration(uint32 \_twapDuration)](#function-settwapdurationuint32-_twapduration)


## Function: `setMaxTotalSupply(uint256 \_maxTotalSupply)`

Sets the total max supply for the optimizer, which is used to determine how many tokens can be minted.

### Preconditions

This can only be called by the owner.

### Branches and code coverage

**Intended branches**

- The new max total supply is set.
  - [x] Test coverage

**Negative behavior**

- The caller is not the owner.
  - [x] Negative test?
- The `_maxTotalSupply` is 0.
  - [x] Negative test?

### Inputs

- `_maxTotalSupply`:
  - **Control**: Cannot be 0.
  - **Authorization**: No checks.
  - **Impact**: Will be the new `maxTotalSupply`.

## Function: `setMaxTwapDeviation(int24 \_maxTwapDeviation)`

Sets the max TWAP deviation.

### Preconditions

This can only be called by the owner.

### Branches and code coverage

**Intended branches**

- Checked.
  - [x] Test coverage
- Unchecked.
  - [ ] Test coverage

**Negative behavior**

- The caller is not the owner.
  - [x] Negative test?
- The new max is less than 20.
  - [x] Negative test?

### Inputs

- `_maxTwapDeviation`:
  - **Control**: Must not be less than 20.
  - **Authorization**: No checks.
  - **Impact**: Will be the new `maxTwapDeviation`.

## Function: `setPriceImpact(uint24 \_priceImpactPercentage)`

Sets the price impact percentage of the optimizer strategy.

### Preconditions

This can only be called by the owner.

### Branches and code coverage

**Intended branches**

- Checked.
  - [x] Test coverage
- Unchecked.
  - [ ] Test coverage

**Negative behavior**

- Caller is not the owner.
  - [x] Negative test?
- The new `priceImpactPercentage` is 0.
  - [x] Negative test?
- The new `priceImpactPercentage` is greater than 1e6.
  - [x] Negative test?

### Inputs

- `_priceImpactPercentage`:
  - **Control**: Must be less than 1e6 and not zero.
  - **Authorization**: No checks.
  - **Impact**: Will be the new `priceImpactPercentage`.

## Function: `setTickRange(int24 \_tickRangeMultiplier)`

Sets the tick range of an optimizer strategy.

### Preconditions

This can only be called by the owner.

### Inputs

- `_tickRangeMultiplier`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: Will be the new `tickRangeMultiplier`.

**Intended branches**

- The new `tickRangeMultiplier` is set.
  - [x] Test coverage

**Negative behavior**

- Caller is not the owner.
  - [x] Negative test?

## Function: `setTwapDuration(uint32 \_twapDuration)`

Sets the TWAP duration.

### Preconditions

This can only be called by the owner.

### Branches and code coverage

**Intended branches**

- The new TWAP duration is set.
  - [x] Test coverage

**Negative behavior**

- The caller is not the owner.
  - [x] Negative test?
- The new `twapDuration` is less than 100.
  - [x] Negative test?

### Inputs

- `_twapDuration`:
  - **Control**: Must not be less than 100.
  - **Authorization**: No checks.
  - **Impact**: Will be the new `twapDuration`.

