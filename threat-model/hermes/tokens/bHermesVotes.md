# bHermesVotes

- [burn(address from, uint256 amount)](#function-burnaddress-from-uint256-amount)
- [mint(address to, uint256 amount)](#function-mintaddress-to-uint256-amount)


## Function: `burn(address from, uint256 amount)`

Burns `bHermes` gauge tokens.

### Preconditions

Only callable by `bHermes`.

### Branches and code coverage

**Intended branches**

- The tokens are burnt from the correct account.
  - [ ] Test coverage

**Negative behavior**

- The caller is not `bHermes`.
  - [ ] Negative test?

### Inputs

- `from`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The account to burn tokens from.
- `amount`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The amount of tokens that will be burnt.

## Function: `mint(address to, uint256 amount)`

Allow new `bHermes` tokens to be minted.

### Preconditions

Only callable by `bHermes`.

### Branches and code coverage

**Intended branches**

- The tokens are minted and sent to the correct account.
  - [x] Test coverage

**Negative behavior**

- The caller is not `bHermes`.
  - [ ] Negative test?

### Inputs

- `account`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: This address will have the new tokens minted to it.
- `amount`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The amount of tokens to be minted.

