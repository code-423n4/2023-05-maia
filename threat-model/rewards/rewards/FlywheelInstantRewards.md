# FlywheelInstantRewards

- [getAccruedRewards()](#function-getaccruedrewards)


## Function: `getAccruedRewards()`

Calculate the amount of rewards accrued to a strategy since the last update.

### Branches and code coverage

**Intended branches**

- The available rewards are transferred to the rewards contract.
  - [x] Test coverage

**Negative behavior**

- The caller is not the `flywheel` contract.
  - [ ] Negative test?

### Function call analysis

- `rewardsDepot.getRewards()`
  - **What is controllable?** N/A.
  - **If return value controllable, how is it used and how can it go wrong?** The
    return value is the number of rewards accrued for the strategy; it is used
    by the `flywheel` to update the strategy's rewards index.
  - **What happens if it reverts, reenters, or does other unusual controlflow?**
    N/A.

