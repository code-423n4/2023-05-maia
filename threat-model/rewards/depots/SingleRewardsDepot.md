# SingleRewardsDepot

- [getRewards()](#function-getrewards)


## Function: `getRewards()`

Gets the amount of available rewards and transfers them to the rewards contract.

### Preconditions

Only callable by the rewards contract.

### Branches and code coverage

**Intended branches**

- The available rewards are transferred to the rewards contract.
  - [x] Test coverage

**Negative behavior**

- The caller is not the rewards contract.
  - [ ] Negative test?

