# Maia

- [mint(address account, uint256 amount)](#function-mintaddress-account-uint256-amount)


## Function: `mint(address account, uint256 amount)`

Allows new Maia tokens to be minted.

### Preconditions

Only callable by the owner.

### Branches and code coverage

**Intended branches**

- The tokens are minted and sent to the correct account.
  - [x] Test coverage

**Negative behavior**

- The caller is not the owner.
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

