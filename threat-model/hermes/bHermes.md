# bHermes

- [claimOutstanding()](#function-claimoutstanding)
- [transferFrom(address from, address to, uint256 amount)](#function-transferfromaddress-from-address-to-uint256-amount)
- [transfer(address to, uint256 amount)](#function-transferaddress-to-uint256-amount)


## Function: `claimOutstanding()`

Claims all outstanding underlying bHermes utility tokens for `msg.sender`.

### Branches and code coverage

**Intended branches**

- All of `msg.sender`'s unclaimed weight, boost, and governance tokens are transferred to `msg.sender`
  - [x] Test coverage

## Function: `transferFrom(address from, address to, uint256 amount)`

Overrides `ERC20.transferFrom` to ensure that the `from` user has enough unclaimed
tokens to transfer.

### Branches and code coverage

**Intended branches**

- The `from` user has enough unclaimed tokens, and they are sent to the correct address.
  - [ ] Test coverage

**Negative behavior**

- The `from` user does not have enough unclaimed tokens.
  - [ ] Negative test?
- The `msg.sender` has not been approved.
  - [ ] Negative test?

### Inputs

- `from`:
  - **Control**: Full control.
  - **Authorization**: The `from` account must have approved the `msg.sender`.
  - **Impact**: This will be where the tokens are sent from.
- `to`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: This address will receive the tokens.
- `amount`:
  - **Control**: Full control.
  - **Authorization**: The user’s balance minus any of the claimed tokens must be greater than this amount.
  - **Impact**: the caller cannot transfer the amount of tokens more than the unclaimed amount.

### Function call analysis

- `super.transferFrom(from, to, amount)`
  - **What is controllable?** `from`, `to`, and `amount` are controllable.
  - **If return value controllable, how is it used and how can it go wrong?** Not controllable.
  - **What happens if it reverts, reenters, or does other unusual control flow?** The tokens will not be transferred.

## Function: `transfer(address to, uint256 amount)`

Overrides `ERC20.transfer` to ensure that the user has enough unclaimed tokens to transfer.

### Branches and code coverage

**Intended branches**

- The user has enough unclaimed tokens, and they are sent to the correct address.
  - [x] Test coverage

**Negative behavior**

- The user does not have enough unclaimed tokens.
  - [x] Negative test?

### Inputs

- `to`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: This address will receive the tokens.
- `amount`:
  - **Control**: Full control.
  - **Authorization**: The user’s balance minus any of the claimed tokens must be greater than this amount.
  - **Impact**: The caller cannot transfer the amount of tokens more than the unclaimed amount.

### Function call analysis

- `super.transfer(to, amount)`
  - **What is controllable?** `to` and `amount` are controllable.
  - **If return value controllable, how is it used and how can it go wrong?** Not controllable.
  - **What happens if it reverts, reenters, or does other unusual control flow?** The tokens will not be transferred.

