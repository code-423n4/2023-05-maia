# ERC20MultiVotes

- [setMaxDelegates](#function-setmaxdelegates)
- [setContractExceedMaxDelegates](#function-setcontractexceedmaxdelegates)
- [incrementDelegation](#function-incrementdelegation)
- [delegate](#function-delegate)
- [undelegate](#function-undelegate)
- [transfer](#function-transfer)
- [transferFrom](#function-transferfrom)

## Function: `setMaxDelegates`

Allows the owner of the contract to update the `maxDelegates` value. This does not affect the current number of delegates, but it will affect the addition of new ones.

## Function: `setContractExceedMaxDelegates`

Allows the owner of the contract to update the `canContractExceedMaxDelegates` value for an account address. The account should be the contract address.

## Function: `incrementDelegation`

Delegate `amount` votes from the sender to `delegatee`.

**Branches and code coverage**

**Intended branches:**

- `_delegatesVotesCount` was increased by `amount`.
  - [ ] Test coverage
- `userDelegatedVotes` was increased by `amount`.
  - [ ] Test coverage
- `delegatee` added to `_delegates[delegator]` list.
  - [ ] Test coverage
- The last position of `_checkpoints[delegatee]` was increased by `amount`.
  - [ ] Test coverage

**Negative behavior:**

- The caller does not have enough free votes.
  - [ ] Negative test?
- The maximum number of delegates has been reached.
  - [ ] Negative test?

**Inputs**

- `delegatee`:
  - **Control**: Full control.
  - **Authorization**: `delegatee != address(0)`.
  - **Impact**: The address of the user who will be able to use votes to assign weight to gauges.
- `amount`:
  - **Control**: Full control.
  - **Authorization**: The `amount` cannot be more than the free votes.
  - **Impact**: The number of votes available to `delegatee`.

## Function: `delegate`

Allows the delegator to update the single `delegatee`. The call is possible only if the `delegator` has only one `delegatee`.

**Branches and code coverage**

**Intended branches:**

- `newDelegatee` is set as the single `delegate`.
  - [ ] Test coverage
- The old `delegate` is removed.
  - [ ] Test coverage
- The caller does not have any `delegate`.
  - [ ] Test coverage
- All votes of the caller are assigned to the new `delegatee`.
  - [ ] Test coverage

**Negative behavior:**

- The caller has more than one `delegate`.
  - [ ] Negative test?
- The old delegate uses the full `_delegatesVotesCount[delegator][oldDelegatee]` value.
  - [ ] Negative test?

**Inputs**

- `newDelegatee`:
  - **Control**: Full control.
  - **Authorization**: Non-zero address.
  - **Impact**: The address of the `user` who will be able to use votes to assign weight to gauges.

## Function: `undelegate`

Allows the caller to decrease the amount of votes assigned for `delegatee`.

**Branches and code coverage**

**Intended branches:**

- `_delegatesVotesCount` is decreased by `amount`.
  - [ ] Test coverage
- `userDelegatedVotes` is decreased by `amount`.
  - [ ] Test coverage
- `_checkpoints[delegatee]` is decreased by `amount`.
  - [ ] Test coverage

**Negative behavior:**

- `delegatee` does not have enough unused votes.
  - [ ] Negative test?
- `msg.sender` does not have the `delegatee`.
  - [ ] Negative test?

**Inputs**

- `delegatee`:
  - **Control**: Full control.
  - **Authorization**: `_delegates[delegator]` should contain the `delegatee` address.
  - **Impact**: The amount of assigned votes of this `delegatee` will be decreased.
- `amount`:
  - **Control**: Full control.
  - **Authorization**: `userUnusedVotes(delegatee) > amount`.
  - **Impact**: The amount of votes the `delegator` wants to release.

## Function: `transfer`

Allows to transfer tokens from `msg.sender` to the `to` address. But before the transfer, the required number of votes must be released from `delegatee`.

### Branches and code coverage

**Intended branches:**

- The caller has enough free votes for transferring.
  - [ ] Test coverage
- The caller did not have enough free votes but additional votes were released properly.
  - [ ] Test coverage
- The used votes are still given to `delegatee`.
  - [ ] Test coverage

**Negative behavior:**

- The caller does not own any tokens.
  - [ ] Negative test?
- The caller does not have enough free tokens and all votes given to `delegatee` are used.
  - [ ] Negative test?

### Inputs

- `to`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The receiver of tokens.
- `amount`:
  - **Control**: Full control.
  - **Authorization**: If the caller does not have enough tokens, the transaction will revert inside the ERC20 transfer function.
  - **Impact**: The amount of tokens to transfer to the other user.

## Function: `transferFrom`

The same function as `transfer`, but `msg.sender` should be assigned by `from` for transferring, or `msg.sender` is `from` address.

