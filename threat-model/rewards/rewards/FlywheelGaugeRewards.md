# FlywheelGaugeRewards

- [queueRewardsForCycle](#function-queuerewardsforcycle)
- [queueRewardsForCyclePaginated](#function-queuerewardsforcyclepaginated)
- [getAccruedRewards](#function-getaccruedrewards)


## Function: `queueRewardsForCycle`

The function iterates over all live gauges and queues up the rewards for the cycle. It is available for any callers. It returns the total reward for the cycle.

### Branches and code coverage

**Intended branches:**

- The `totalQueuedForCycle` value is expected.
  - [ ] Test coverage

**Negative behavior:**

- `minter.getRewards()` returned zero.
  - [ ] Negative test?
- The current cycle is equal to or less than `lastCycle`.
  - [ ] Negative test?

### Function call analysis

- `address(minter).call("")`
  - **What is controllable?** Nothing.
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?** N/A.
- `minter.getRewards()`
  - **What is controllable?** Nothing.
  - **If return value controllable, how is it used and how can it go wrong?** Returns the amount of reward tokens that were transferred to the current contract.
  - **What happens if it reverts, reenters, or does other unusual control flow?** Can revert if `minter` does not have enough tokens.
- `rewardToken.balanceOf(address(this))`
  - **What is controllable?** Nothing.
  - **If return value controllable, how is it used and how can it go wrong?** No problem.
  - **What happens if it reverts, reenters, or does other unusual control flow?** No problem.
- `gaugeToken.calculateGaugeAllocation(address(gauge), totalQueuedForCycle)`
  - **What is controllable?** Nothing.
  - **If return value controllable, how is it used and how can it go wrong?** If the function were controlled by an attacker, they could manipulate the value of the assigned reward.
  - **What happens if it reverts, reenters, or does other unusual control flow?** No problem.

## Function: `queueRewardsForCyclePaginated`

The function iterates over `amount` live gauges and queues up the rewards for the cycle. It is available for any callers.

### Branches and code coverage

**Intended branches:**

- `numRewards` is more than `remaining`.
  - [ ] Test coverage
- `numRewards` is less than `remaining`.
  - [ ] Test coverage
- `numRewards` is equal to `remaining`.
  - [ ] Test coverage
- `paginationOffset` is zero.
  - [ ] Test coverage

### Inputs

- `numRewards`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The number of rewards that will be placed in the queue.

### Function call analysis

- `address(minter).call("")`
  - **What is controllable?** Nothing.
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?** N/A.
- `minter.getRewards()`
  - **What is controllable?** Nothing.
  - **If return value controllable, how is it used and how can it go wrong?** Returns the amount of reward tokens that were transferred to the current contract.
  - **What happens if it reverts, reenters, or does other unusual control flow?** Can revert if `minter` does not have enough tokens.
- `rewardToken.balanceOf(address(this))`
  - **What is controllable?** Nothing.
  - **If return value controllable, how is it used and how can it go wrong?** No problem.
  - **What happens if it reverts, reenters, or does other unusual control flow?** No problem.
- `gaugeToken.calculateGaugeAllocation(address(gauge), totalQueuedForCycle)`
  - **What is controllable?** Nothing.
  - **If return value controllable, how is it used and how can it go wrong?** If the function were controlled by an attacker, they could manipulate the value of the assigned reward.
  - **What happens if it reverts, reenters, or does other unusual control flow?** No problem.

## Function: `getAccruedRewards`

### Branches and code coverage

**Negative behavior:**

- `msg.sender` does not have a reward.
  - [ ] Negative test?
- Repeated calls after successful transfer.
  - [ ] Negative test?

### Function call analysis

- `address(minter).call("")`
  - **What is controllable?** Nothing.
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?** N/A.
- `rewardToken.safeTransfer(msg.sender, accruedRewards)`
  - **What is controllable?** Nothing.
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?** N/A.

