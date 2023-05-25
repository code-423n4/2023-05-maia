# UtilityManager

- [claimWeight](#function-claimweight)
- [claimBoost](#function-claimboost)
- [claimGovernance](#function-claimgovernance)
- [forfeitWeight](#function-forfeitweight)
- [forfeitBoost](#function-forfeitboost)
- [forfeitGovernance](#function-forfeitgovernance)


## Function: `claimWeight`

Allows to transfer the `amount` of weight utility tokens to the `msg.sender`. Before the transfer, there should be a check that `msg.sender` has more or an equal amount of current tokens.

### Branches and code coverage

**Intended branches:**

- The `msg.sender` received the expected amount of weight utility tokens.
  - [ ] Test coverage

**Negative behavior:**

- The `balanceOf(msg.sender)` is less than `amount` if `userClaimedWeight[msg.sender] == 0`.
  - [ ] Negative test?
- The `balanceOf(msg.sender)` is less than `amount + userClaimedWeight[msg.sender]`.
  - [ ] Negative test?

### Inputs

- `amount`:
  - **Control**: Full control.
  - **Authorization**: `balanceOf(msg.sender)` should be more or equal to `amount + userClaimedWeight[msg.sender]`.
  - **Impact**: `msg.sender` should not be able to receive an arbitrary amount of weight utility tokens.

### Function call analysis

- `address(gaugeWeight).safeTransfer(msg.sender, amount)`
  - **What is controllable?** `amount`.
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value here.
  - **What happens if it reverts, reenters, or does other unusual control flow?** Will revert if the current contract does not have enough tokens.

## Function: `claimBoost`

Allows to transfer the `amount` of boost utility tokens to the `msg.sender`. Before the transfer, there should be a check that `msg.sender` has more or an equal amount of current tokens.

### Branches and code coverage

**Intended branches:**

- The `msg.sender` received the expected amount of boost utility tokens.
  - [ ] Test coverage

**Negative behavior:**

- The `balanceOf(msg.sender)` is less than `amount` if `userClaimedBoost[msg.sender] == 0`.
  - [ ] Negative test?
- The `balanceOf(msg.sender)` is less than `amount + userClaimedBoost[msg.sender]`.
  - [ ] Negative test?

### Inputs

- `amount`:
  - **Control**: Full control.
  - **Authorization**: `balanceOf(msg.sender)` should be more or equal to `amount + userClaimedBoost[msg.sender]`.
  - **Impact**: `msg.sender` should not be able to receive an arbitrary amount of boost utility tokens.

### Function call analysis

- `address(gaugeBoost).safeTransfer(msg.sender, amount)`
  - **What is controllable?** `amount`.
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value here.
  - **What happens if it reverts, reenters, or does other unusual control flow?** Will revert if the current contract does not have enough tokens.

## Function: `claimGovernance`

Allows to transfer the `amount` of governance utility tokens to the `msg.sender`. Before the transfer, there should be a check that `msg.sender` has more or an equal amount of current tokens.

### Branches and code coverage

**Intended branches:**

- The `msg.sender` received the expected amount of governance utility tokens.
  - [ ] Test coverage

**Negative behavior:**

- The `balanceOf(msg.sender)` is less than `amount` if `userClaimedGovernance[msg.sender] == 0`.
  - [ ] Negative test?
- The `balanceOf(msg.sender)` is less than `amount + userClaimedGovernance[msg.sender]`.
  - [ ] Negative test?

### Inputs

- `amount`:
  - **Control**: Full control.
  - **Authorization**: `balanceOf(msg.sender)` should be more or equal to `amount + userClaimedGovernance[msg.sender]`.
  - **Impact**: `msg.sender` should not be able to receive an arbitrary amount of governance utility tokens.

### Function call analysis

- `address(governance).safeTransfer(msg.sender, amount)`
  - **What is controllable?** `amount`.
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value here.
  - **What happens if it reverts, reenters, or does other unusual control flow?** Will revert if the current contract does not have enough tokens.

## Function: `forfeitWeight`

Allows `msg.sender` to revoke the weight utility tokens. Before the transfer, there should be a check that `userClaimedWeight[msg.sender]` is more than or equal to `amount`.

### Branches and code coverage

**Intended branches:**

- The `userClaimedWeight` for `msg.sender` is decreased by `amount`.
  - [ ] Test coverage

**Negative behavior:**

- `userClaimedWeight[msg.sender]` is less than `amount`.
  - [ ] Negative test?

### Inputs

- `amount`:
  - **Control**: Full control.
  - **Authorization**: `userClaimedWeight[msg.sender]` should be more than or equal to `amount`.
  - **Impact**: `msg.sender` should not be able to revoke an arbitrary amount of weight utility tokens.

### Function call analysis

- `address(gaugeWeight).safeTransferFrom(msg.sender, address(this), amount)`
  - **What is controllable?** `amount`.
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value here.
  - **What happens if it reverts, reenters, or does other unusual control flow?** Will revert if `msg.sender` does not have enough tokens.

## Function: `forfeitBoost`

Allows `msg.sender` to revoke the boost utility tokens. Before the transfer, there should be a check that `userClaimedBoost` for `msg.sender` is more than or equal to `amount`.

### Branches and code coverage

**Intended branches:**

- The `userClaimedBoost` for `msg.sender` is decreased by `amount`.
  - [ ] Test coverage

**Negative behavior:**

- `userClaimedBoost[msg.sender]` is less than `amount`.
  - [ ] Negative test?

### Inputs

- `amount`:
  - **Control**: Full control.
  - **Authorization**: `userClaimedBoost[msg.sender]` should be more than or equal to `amount`.
  - **Impact**: `msg.sender` should not be able to revoke an arbitrary amount of boost utility tokens.

### Function call analysis

- `address(gaugeBoost).safeTransferFrom(msg.sender, address(this), amount)`
  - **What is controllable?** `amount`.
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value here.
  - **What happens if it reverts, reenters, or does other unusual control flow?** Will revert if `msg.sender` does not have enough tokens.

## Function: `forfeitGovernance`

Allows `msg.sender` to revoke the governance utility tokens. Before the transfer, there should be a check that `userClaimedGovernance` for `msg.sender` is more than or equal to `amount`.

### Branches and code coverage

**Intended branches:**

- The `userClaimedGovernance` for `msg.sender` is decreased by `amount`.
  - [ ] Test coverage

**Negative behavior:**

- `userClaimedGovernance[msg.sender]` is less than `amount`.
  - [ ] Negative test?

### Inputs

- `amount`:
  - **Control**: Full control.
  - **Authorization**: `userClaimedGovernance[msg.sender]` should be more than or equal to `amount`.
  - **Impact**: `msg.sender` should not be able to revoke an arbitrary amount of governance utility tokens.

### Function call analysis

- `address(governance).safeTransferFrom(msg.sender, address(this), amount)`
  - **What is controllable?** `amount`.
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value here.
  - **What happens if it reverts, reenters, or does other unusual control flow?** Will revert if `msg.sender` does not have enough tokens.

