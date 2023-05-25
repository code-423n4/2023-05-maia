# FlywheelAcummulatedRewards

- [getAccruedRewards](#function-getaccruedrewards)


The `FlywheelBribeRewards` contract is inherited from this contract.

## Function: `getAccruedRewards`

Allows calculating the amount of rewards accrued to a strategy since the last update. The function should be called only by the `flywheel` contract, which was set during deployment.

### Branches and code coverage

**Intended branches:**

- The amount value is expected.
  - [ ] Test coverage

**Negative behavior:**

- The caller is not the trusted `flywheel` contract.
  - [ ] Negative test?
- The `rewardsDepots` does not contain the strategy address.
  - [ ] Negative test?

### Inputs

- `strategy`:
  - **Control**: Full control.
  - **Authorization**: If there is no `rewardsDepots` for this strategy, the transaction will revert as the zero address will be called.
  - **Impact**: The corresponding `rewardsDepots` for this `strategyAddress` will be called. Since addresses for malicious contracts can be stored inside the `rewardsDepots` lists, the caller should only use the trusted `strategyAddress`.

### Function call analysis

- `rewardsDepots[strategy].getRewards() -> _asset.safeTransfer(_rewardsContract, balance);`
  - **What is controllable?** `strategy` is controlled by functions available only for the `flywheel` contract, which can use only the trusted `strategy`.
  - **If return value controllable, how is it used and how can it go wrong?** The amount of reward that was transferred. If this value is more than actually transferred during reward claiming, the users will receive more reward than they should.
  - **What happens if it reverts, reenters, or does other unusual control flow?** No problems.

