# UniswapV3GaugeFactory

- [setMinimumWidth(address gauge, uint24 minimumWidth)](#function-setminimumwidthaddress-gauge-uint24-minimumwidth)


## Function: `setMinimumWidth(address gauge, uint24 minimumWidth)`

Sets the minimum width for a gauge.

### Preconditions

Only callable by the owner.

### Branches and code coverage

**Intended branches**

- The gauge's minimum width is updated, and the Uniswap V3 staker is notified.
  - [ ] Test coverage

**Negative behavior**

- The caller is not the owner.
  - [x] Negative test?

### Inputs

- `gauge`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: Will have `setMinimumWidth` called on it.
- `minimumWidth`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: Will be the new minimum width of the gauge.

### Function call analysis

- `UniswapV3Gauge(gauge).setMinimumWidth(minimumWidth)`:
  - **What is controllable?** Both `gauge` and `minimumWidth` are fully controllable.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual controlflow?** The width will not be updated.

