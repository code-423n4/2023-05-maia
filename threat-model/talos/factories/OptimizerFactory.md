# OptimizerFactory

- [createTalosOptimizer(uint32 \_twapDuration, int24 \_maxTwapDeviation, int24 \_tickRangeMultiplier, uint24 \_priceImpactPercentage, uint256 \_maxTotalSupply, address owner)](#function-createtalosoptimizeruint32-_twapduration-int24-_maxtwapdeviation-int24-_tickrangemultiplier-uint24-_priceimpactpercentage-uint256-_maxtotalsupply-address-owner)


## Function: `createTalosOptimizer(uint32 \_twapDuration, int24 \_maxTwapDeviation, int24 \_tickRangeMultiplier, uint24 \_priceImpactPercentage, uint256 \_maxT`otalSupply, address owner)

Creates a new optimizer for use in a Talos strategy.

### Branches and code coverage

**Intended branches**

- A new optimizer is created and added to the list.
  - [ ] Test coverage

### Inputs

- `_twapDuration`:
  - **Control**: Must be less than 100.
  - **Authorization**: No checks.
  - **Impact**: Sets the TWAP duration in seconds for rebalance check.
- `_maxTwapDeviation`:
  - **Control**: Must be less than 20.
  - **Authorization**: No checks.
  - **Impact**: Sets the max deviation from TWAP during rebalance.
- `_tickRangeMultiplier`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: Used to determine base order range.
- `_priceImpactPercentage`:
  - **Control**: Must not be zero or greater than 1e6.
  - **Authorization**: No checks.
  - **Impact**: The price impact percentage during swap in hundredths of a bip (i.e., 1e6).
- `_maxTotalSupply`:
  - **Control**: Must not be zero.
  - **Authorization**: No checks.
  - **Impact**: Maximum TLP value that could be minted.
- `owner`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: This will be the owner of the optimizer.

