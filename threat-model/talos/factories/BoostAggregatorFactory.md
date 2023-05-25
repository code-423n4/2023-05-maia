# BoostAggregatorFactory

- [createBoostAggregator(address owner)](#function-createboostaggregatoraddress-owner)


## Function: `createBoostAggregator(address owner)`

Creates a new boost aggregator using the factories `uniswapV3Staker` and Hermes token.

### Branches and code coverage

**Intended branches**

- A new boost aggregator is created and added to the list.
  - [ ] Test coverage

**Negative behavior**

- The owner is the 0 address.
  - [ ] Negative test?

### Inputs

- owner:
  - **Control**: Cannot be 0.
  - **Authorization**: No checks.
  - **Impact**: Will be the owner of the boost aggregator.

